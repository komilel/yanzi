#include <sys/stat.h>
#include <unistd.h>

#include <filesystem>
#include <fstream>
#include <iostream>
#include <stdexcept>
#include <string>
#include <vector>

#include "cvext.hpp"
#include "drv_fpc/fingerprint.hpp"

static void require(bool condition, const char* message) {
    if (!condition) {
        throw std::runtime_error(message);
    }
}

int main() {
    char directory[] = "/tmp/fingerprint-ocv-tests-XXXXXX";
    if (!mkdtemp(directory)) {
        return 1;
    }
    const std::filesystem::path root(directory);
    ::umask(0077);

    try {
        // Synthetic pixels only: these tests never capture real fingerprints.
        cv::Mat image(176, 224, CV_8UC1);
        cv::RNG random(9201);
        random.fill(image, cv::RNG::UNIFORM, 0, 256);
        cv::Mat mask(image.size(), CV_32F, cv::Scalar(1));
        cv::Mat blank(image.size(), CV_8UC1, cv::Scalar(0));
        cv::Mat unrelated(image.size(), CV_8UC1);
        random.fill(unrelated, cv::RNG::UNIFORM, 0, 256);

        require(cvext::match(image, mask, image, 4, 0.30, false),
                "Identical synthetic images should match");
        require(!cvext::match(image, mask, blank, 4, 0.30, false),
                "A featureless scan must not match");
        require(!cvext::match(image, mask, unrelated, 4, 0.30, false),
                "Unrelated synthetic images must not match");
        cv::Mat merged, merged_mask;
        require(!cvext::merge(image, mask, blank, merged, merged_mask),
                "A featureless scan must not merge or crash");

        const auto database = root / "templates.bin";
        const std::vector<unsigned char> key(32, 0x42);
        fpc::FingerprintStorage storage;
        storage.init(database.string(), key);
        require(storage.get_enrolled_count("test-user") == 0,
                "A missing database should be empty");

        fpc::Fingerprint print;
        print._user = "test-user";
        print._name = "right-index-finger";
        require(print.merge(image), "First scan should initialize a template");
        storage.insert_or_update(std::move(print));
        storage.save();

        struct stat status{};
        require(::stat(database.c_str(), &status) == 0, "Database must be saved");
        require((status.st_mode & 0777) == 0600, "Database must be owner-only");
        require(!std::filesystem::exists(database.string() + ".tmp"),
                "Successful atomic save must not leave a temporary file");

        fpc::FingerprintStorage loaded;
        loaded.init(database.string(), key);
        require(loaded.check("test-user", "right-index-finger"),
                "Encrypted template must survive a save/load round trip");
        require(loaded.get_enrolled_count("another-user") == 0,
                "Templates must be separated by account");
        bool round_trip_matches = false;
        loaded.foreach("test-user", [&](const fpc::Fingerprint& saved) {
            round_trip_matches = saved.match(image, 0.30, false);
            return true;
        });
        require(round_trip_matches, "Loaded template must retain its image");

        fpc::FingerprintStorage wrong_key;
        wrong_key.init(database.string(), std::vector<unsigned char>(32, 0x43));
        require(wrong_key.get_enrolled_count("test-user") == 0,
                "Invalid database authentication must fail closed");

        // Overwrite the existing file, then confirm deletion is persistent.
        require(loaded.delete_fingerprint("test-user", "right-index-finger"),
                "Enrolled template must be deletable");
        loaded.save();
        fpc::FingerprintStorage deleted;
        deleted.init(database.string(), key);
        require(deleted.get_enrolled_count("test-user") == 0,
                "Deleted templates must not reappear after reload");

        const auto truncated = root / "truncated.bin";
        std::ofstream(truncated) << "short";
        fpc::FingerprintStorage invalid;
        invalid.init(truncated.string(), key);
        require(invalid.get_enrolled_count("test-user") == 0,
                "Truncated database must fail closed");

        // Regression: upstream used to dereference a null FILE* on failure.
        fpc::FingerprintStorage unwritable;
        unwritable.init((root / "missing-directory" / "templates.bin").string(), key);
        unwritable.save();

        std::filesystem::remove_all(root);
        std::cout << "Matching and template storage regressions passed\n";
        return 0;
    } catch (const std::exception& error) {
        std::cerr << error.what() << '\n';
        std::filesystem::remove_all(root);
        return 1;
    }
}
