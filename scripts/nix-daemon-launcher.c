/* Keep a stable, dedicated process responsible for external-volume access.
 * Only launches the root-managed Nix daemon; accepts no executable arguments.
 * See https://github.com/NixOS/nix/issues/6291 .
 */
#include <errno.h>
#include <signal.h>
#include <stdio.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <unistd.h>

static volatile sig_atomic_t child_pid = -1;

static void forward_signal(int signal_number) {
    if (child_pid > 0) kill((pid_t)child_pid, signal_number);
}

int main(int argc, char **argv) {
    (void)argv;
    if (argc != 1 || geteuid() != 0) {
        fputs("Run this launcher as root, with no arguments.\n", stderr);
        return 64;
    }
    const char *daemon = "/run/current-system/sw/bin/nix-daemon";
    if (access(daemon, X_OK) != 0)
        daemon = "/nix/var/nix/profiles/default/bin/nix-daemon";
    for (int attempt = 0; access(daemon, X_OK) != 0; attempt++) {
        if (attempt == 60) {
            perror("Nix daemon unavailable; check mount and privacy permission");
            return 1;
        }
        sleep(1);
    }
    sigset_t blocked, previous;
    sigemptyset(&blocked);
    sigaddset(&blocked, SIGTERM);
    sigaddset(&blocked, SIGINT);
    sigaddset(&blocked, SIGHUP);
    if (sigprocmask(SIG_BLOCK, &blocked, &previous) < 0) return 1;
    pid_t child = fork();
    if (child < 0) { perror("fork"); return 1; }
    if (child == 0) {
        sigprocmask(SIG_SETMASK, &previous, NULL);
        execl(daemon, daemon, (char *)NULL);
        perror("exec Nix daemon");
        _exit(1);
    }
    child_pid = child;
    struct sigaction action = {0};
    action.sa_handler = forward_signal;
    sigemptyset(&action.sa_mask);
    sigaction(SIGTERM, &action, NULL);
    sigaction(SIGINT, &action, NULL);
    sigaction(SIGHUP, &action, NULL);
    sigprocmask(SIG_SETMASK, &previous, NULL);
    int status;
    while (waitpid(child, &status, 0) < 0) {
        if (errno != EINTR) { perror("waitpid"); return 1; }
    }
    return WIFEXITED(status) ? WEXITSTATUS(status) : 128 + WTERMSIG(status);
}
