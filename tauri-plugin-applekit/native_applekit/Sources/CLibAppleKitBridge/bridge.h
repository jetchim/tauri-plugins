#ifdef __cplusplus
extern "C" {
#endif

const void set_user_default(const char* keyPtr, const char* valuePtr);

const char* get_user_default(const char* keyPtr);

const int save_keychain(const char* keyPtr, const char* valuePtr);

const char* load_keychain(const char* keyPtr);

#ifdef __cplusplus
}
#endif
