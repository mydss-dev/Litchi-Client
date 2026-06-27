#include <jni.h>
#include <mutex>
#include "liblitchi_mihomo.h"

extern "C" void (*litchi_protect_socket_func)(void *, int);

static JavaVM *g_vm = nullptr;
static jobject g_service = nullptr;
static jmethodID g_protect = nullptr;
static std::mutex g_lock;

static JNIEnv *attach_env(bool *attached) {
    JNIEnv *env = nullptr;
    *attached = false;
    if (g_vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        if (g_vm->AttachCurrentThread(&env, nullptr) != JNI_OK) return nullptr;
        *attached = true;
    }
    return env;
}

static void protect_socket(void *, int fd) {
    if (g_vm == nullptr || g_protect == nullptr) return;

    bool attached = false;
    JNIEnv *env = attach_env(&attached);
    if (env == nullptr) return;

    // Safely obtain a local ref under the lock so DeleteGlobalRef in
    // release_service() cannot race with a concurrent protect_socket() call.
    jobject service_ref = nullptr;
    {
        std::lock_guard<std::mutex> guard(g_lock);
        if (g_service != nullptr) {
            service_ref = env->NewLocalRef(g_service);
        }
    }

    if (service_ref != nullptr) {
        env->CallBooleanMethod(service_ref, g_protect, fd);
        if (env->ExceptionCheck()) env->ExceptionClear();
        env->DeleteLocalRef(service_ref);
    }

    if (attached) g_vm->DetachCurrentThread();
}

static void release_service(JNIEnv *env) {
    std::lock_guard<std::mutex> guard(g_lock);
    if (g_service != nullptr) {
        env->DeleteGlobalRef(g_service);
        g_service = nullptr;
    }
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_litchi_client_AndroidMihomoEngine_nativeStart(
    JNIEnv *env,
    jobject,
    jstring config,
    jstring home,
    jint fd,
    jobject service
) {
    release_service(env);
    {
        std::lock_guard<std::mutex> guard(g_lock);
        g_service = env->NewGlobalRef(service);
    }

    const char *config_chars = env->GetStringUTFChars(config, nullptr);
    const char *home_chars = env->GetStringUTFChars(home, nullptr);
    char *error = litchiMihomoStart(
        const_cast<char *>(config_chars),
        const_cast<char *>(home_chars),
        fd,
        g_service
    );

    bool ok = error == nullptr || error[0] == '\0';

    env->ReleaseStringUTFChars(config, config_chars);
    env->ReleaseStringUTFChars(home, home_chars);

    jstring result = env->NewStringUTF(ok ? "" : error);

    if (error != nullptr) litchiMihomoFree(error);

    if (!ok) {
        release_service(env);
    }

    return result;
}

extern "C"
JNIEXPORT void JNICALL
Java_com_litchi_client_AndroidMihomoEngine_nativeStop(JNIEnv *env, jobject) {
    litchiMihomoStop();
    release_service(env);
}

extern "C"
JNIEXPORT jstring JNICALL
Java_com_litchi_client_AndroidMihomoEngine_nativeVersion(JNIEnv *env, jobject) {
    char *value = litchiMihomoVersion();
    jstring result = env->NewStringUTF(value == nullptr ? "mihomo" : value);
    if (value != nullptr) litchiMihomoFree(value);
    return result;
}

JNIEXPORT jint JNICALL JNI_OnLoad(JavaVM *vm, void *) {
    g_vm = vm;
    JNIEnv *env = nullptr;
    if (vm->GetEnv(reinterpret_cast<void **>(&env), JNI_VERSION_1_6) != JNI_OK) {
        return JNI_ERR;
    }
    jclass service = env->FindClass("com/litchi/client/LitchiVpnService");
    if (service == nullptr) return JNI_ERR;
    g_protect = env->GetMethodID(service, "protect", "(I)Z");
    env->DeleteLocalRef(service);
    if (g_protect == nullptr) return JNI_ERR;
    litchi_protect_socket_func = protect_socket;
    return JNI_VERSION_1_6;
}
