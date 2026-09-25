/* The console build (ci/build.sh psc): gcc-12's C++ headers and its static libstdc++ against the console's own
 * glibc 2.24 (the Debian Stretch sysroot in the build image). Those were written for a newer glibc; this header,
 * force-included into every C++ file, declares the five timed-wait functions they call, and glibc_compat.c
 * defines them - and the three other symbols the static libstdc++ needs - over what glibc 2.24 has. */
#ifndef PSC_GLIBC_COMPAT_H
#define PSC_GLIBC_COMPAT_H
#include <pthread.h>
#include <semaphore.h>
#include <time.h>
#ifdef __cplusplus
extern "C" {
#endif
int pthread_cond_clockwait(pthread_cond_t *, pthread_mutex_t *, clockid_t, const struct timespec *);
int pthread_mutex_clocklock(pthread_mutex_t *, clockid_t, const struct timespec *);
int pthread_rwlock_clockrdlock(pthread_rwlock_t *, clockid_t, const struct timespec *);
int pthread_rwlock_clockwrlock(pthread_rwlock_t *, clockid_t, const struct timespec *);
int sem_clockwait(sem_t *, clockid_t, const struct timespec *);
#ifdef __cplusplus
}
#endif
#endif
