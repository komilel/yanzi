/* Rootless PAM control-flow fixture: no passwords, USB or system config. */
#include <security/pam_modules.h>
#include <stdio.h>
#include <stdlib.h>

PAM_EXTERN int pam_sm_authenticate(pam_handle_t *pamh, int flags,
                                  int argc, const char **argv) {
    if (argc < 1) return PAM_SYSTEM_ERR;
    const char *trace = pam_getenv(pamh, "TRACE");
    const char *result = pam_getenv(pamh, argv[0]);
    if (!trace || !result) return PAM_SYSTEM_ERR;
    FILE *file = fopen(trace, "a");
    if (!file) return PAM_SYSTEM_ERR;
    fprintf(file, "%s\n", argv[0]);
    fclose(file);
    return atoi(result);
}

PAM_EXTERN int pam_sm_acct_mgmt(pam_handle_t *pamh, int flags,
                               int argc, const char **argv) {
    return pam_sm_authenticate(pamh, flags, argc, argv);
}

PAM_EXTERN int pam_sm_setcred(pam_handle_t *pamh, int flags,
                            int argc, const char **argv) {
    return PAM_SUCCESS;
}
