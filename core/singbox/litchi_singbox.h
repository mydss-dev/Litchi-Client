#ifndef LITCHI_SINGBOX_H
#define LITCHI_SINGBOX_H

#if defined(_WIN32)
#define LITCHI_API __declspec(dllimport)
#else
#define LITCHI_API
#endif

#ifdef __cplusplus
extern "C" {
#endif

LITCHI_API int litchi_core_check_config(const char *config,
                                        const char *work_dir);
LITCHI_API int litchi_core_start(const char *config, const char *work_dir);
LITCHI_API int litchi_core_stop(void);
LITCHI_API int litchi_core_is_running(void);
LITCHI_API char *litchi_core_version(void);
LITCHI_API char *litchi_core_last_error(void);
LITCHI_API void litchi_core_free_string(char *value);

#ifdef __cplusplus
}
#endif

#endif
