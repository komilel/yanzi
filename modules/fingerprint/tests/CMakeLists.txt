
# Hardware-free regression checks supplied by the Nix package.
if(BUILD_TESTING)
  find_package(OpenSSL REQUIRED)
  add_executable(fingerprint-ocv-tests
    nix-tests.cpp drv_fpc/fingerprint.cpp drv_fpc/crypto.cpp)
  target_link_libraries(fingerprint-ocv-tests PRIVATE cvext jinx OpenSSL::Crypto)
  add_test(NAME fingerprint-ocv-regressions COMMAND fingerprint-ocv-tests)
  set_tests_properties(fingerprint-ocv-regressions PROPERTIES TIMEOUT 30)
  add_executable(fingerprint-ocv-device-fixture
    nix-device-fixture.cpp drv_fpc/fingerprint.cpp drv_fpc/crypto.cpp drv_fpc/fpcbio.cpp)
  target_link_libraries(fingerprint-ocv-device-fixture PRIVATE
    manager cvext jinx::openssl OpenSSL::SSL OpenSSL::Crypto)
endif()
