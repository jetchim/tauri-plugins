#ifdef __cplusplus
extern "C" {
#endif

const void set_user_default(const char* keyPtr, const char* valuePtr);

const char* get_user_default(const char* keyPtr);

const int save_keychain(const char* keyPtr, const char* valuePtr);

const char* load_keychain(const char* keyPtr);

const void hud_show(const int windowNumber);

const void close_hud(const int windowNumber);

#ifdef __cplusplus
}
#endif
