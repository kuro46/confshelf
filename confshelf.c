#include <stdio.h>
#include <sys/stat.h>
#include <errno.h>
#include <unistd.h>
#include <stdlib.h>
#include <string.h>
#include <sys/stat.h>
#include <stdbool.h>
#include <assert.h>
#include <git2.h>
#include "toml.h"

static const int CMD_SETUP = 0b01;
static const int CMD_PULL = 0b01 << 1;
static const int CMD_PUSH = 0b01 << 2;
static const int CMD_COMMIT = 0b01 << 3;
static const int CMD_MANAGE = 0b01 << 4;
static const int CMD_UNMANAGE = 0b01 << 5;
static const int CMD_LINK = 0b01 << 6;
static const int CMD_STATUS = 0b01 << 7;

static void error(const char *msg, const char *cause)
{
	if (cause) {
		fprintf(stdout, "ERROR: %s - %s\n", msg, cause);
	} else {
		fprintf(stdout, "ERROR: %s\n", msg);
	}
	exit(1);
}

char* get_app_dir(char *suffix) 
{
	char *user_home = getenv("HOME");
	if (!user_home)
	{
		error("\"HOME\" variable not set!", NULL);
	}
	char *middle = "/.confshelf/";
	char *app_home = (char*) calloc(strlen(user_home) + strlen(middle) + strlen(suffix) + 1, sizeof(char));
	if (app_home == NULL)
	{
		error("calloc fail", NULL);
	}
	strcat(app_home, user_home);
	strcat(app_home, middle);
	strcat(app_home, suffix);
	return app_home;
}

char* get_repo_dir_path()
{
	return get_app_dir("repo/");
}

char* get_path_relative_to_repo_dir(char* suffix) {
	char *repo_dir = get_repo_dir_path();
	char *appended = (char*) calloc(strlen(repo_dir) + strlen(suffix) + 1, sizeof(char));
	if (appended == NULL)
	{
		error("calloc failed", NULL);
	}
	strcat(appended, repo_dir);
	strcat(appended, suffix);
	free(repo_dir);
	return appended;
}

char* get_config_file_path()
{
	return get_app_dir("config.toml");
}
char* get_known_links_file_path()
{
	return get_app_dir("known_links.toml");
}

void usage(char *argv[])
{
	printf("Usage: %s <help|setup|pull|push|commit|manage|unmanage|link|status>\n", argv[0]);
}

bool git_repo_exists(const char *path)
{
	return git_repository_open_ext(
			NULL, path, GIT_REPOSITORY_OPEN_NO_SEARCH, NULL) == 0;
}

void setup(char *argv[])
{
	git_libgit2_init();
	char *repo_dir = get_repo_dir_path();
	git_repository* repo = NULL;
	git_repository_init_options opts = GIT_REPOSITORY_INIT_OPTIONS_INIT;
	opts.flags |= GIT_REPOSITORY_INIT_NO_REINIT;
	int gerror = git_repository_init_ext(&repo, repo_dir, &opts);
	if (gerror != 0)
	{
		if (gerror == GIT_EEXISTS) 
		{
			error("confshelf is already set up!", NULL);
		}
		const git_error *e = git_error_last();
		error("Repository init failed", e->message);
	}
	printf("Repository initialized!\n");
	git_repository_free(repo);
	free(repo_dir);
	repo_dir = NULL;
	git_libgit2_shutdown();
}

void pull(char *argv[])
{
}

void push(char *argv[])
{
}

void commit(char *argv[])
{
}

bool path_exists(char *path)
{
	struct stat st;
	return stat(path, &st) == 0;
}

bool is_file(char *path)
{
	struct stat st;
	errno = 0;
	if (stat(path, &st) != 0)
	{
		fprintf(stderr, "ERROR: Fail to retrieve stat of \"%s\": %s", path, strerror(errno));
		exit(1);
	}
	return S_ISREG(st.st_mode);
}

// Success: 0 Fail: != 0
int insert_known_links(char *link_path, char *dst_path)
{
	assert(link_path != NULL && dst_path != NULL);
	char *known_links_path = get_known_links_file_path();
	errno = 0;
	FILE *known_links_file = fopen(known_links_path, "a");
	if (known_links_file == NULL)
	{
		fprintf(stderr, "ERROR: Failed to open \"%s\": %s\n",
				known_links_path, strerror(errno));
		return 1;
	}
	fprintf(known_links_file, "\"%s\" = \"%s\"\n", link_path, dst_path);
	fclose(known_links_file);
	free(known_links_path);
	known_links_path = NULL;
	return 0;
}

int manage(int argc, char *argv[])
{
	if (argc < 4)
	{
		fprintf(stderr, "Usage: %s manage <src path> <dst path>\n", argv[0]);
		return 1;
	}
	char *src = argv[2];
	char *dst_file_name = argv[3];
	char *dst_path = get_path_relative_to_repo_dir(argv[3]);
	if (!path_exists(src))
	{
		fprintf(stderr, "ERROR: \"%s\" not exists\n", src);
		return 1;
	}
	if (!is_file(src)) {
		fprintf(stderr, "ERROR: \"%s\" is not a regular file\n", src);
		return 1;
	}
	if (path_exists(dst_path))
	{
		fprintf(stderr, "ERROR: \"%s\" already exists\n", dst_path);
		return 1;
	}
	errno = 0;
	if (rename(src, dst_path) != 0)
	{
		fprintf(stderr, "ERROR: Failed to move from \"%s\" to \"%s\": %s\n",
				src, dst_path, strerror(errno));
		return 1;
	}
	errno = 0;
	if (symlink(dst_path, src) != 0)
	{
		fprintf(stderr, "ERROR: Failed to create symlink (link: \"%s\", dst: \"%s\"): %s\n",
				src, dst_path, strerror(errno));
		return 1;
	}
	int ins_result = insert_known_links(src, dst_file_name);
	free(dst_path);
	dst_path = NULL;
	if (ins_result == 0)
	{
		printf("Success!\n");
		return 0;
	} else {
		printf("Failed\n");
		return 1;
	}
}

void unmanage(char *argv[])
{
}

int cmd_link(int argc, char *argv[])
{
	if (argc < 4)
	{
		printf("Usage: %s link <src path> <symlink path>\n", argv[0]);
		return 1;
	}
	char *src_file_name = argv[2];
	char *src_path = get_path_relative_to_repo_dir(argv[2]);
	char *symlink_path = argv[3];
	if (!path_exists(src_path))
	{
		printf("ERROR: \"%s\" not exists\n", src_path);
		return 1;
	}
	if (!is_file(src_path))
	{
		printf("ERROR: \"%s\" is not a regular file\n", src_path);
		return 1;
	}
	if (path_exists(symlink_path))
	{
		printf("ERROR: \"%s\" already exists\n", symlink_path);
		return 1;
	}
	errno = 0;
	if (symlink(src_path, symlink_path) != 0)
	{
		printf("ERROR: Failed to create symlink (link: \"%s\", dst: \"%s\"): %s\n",
				symlink_path, src_path, strerror(errno));
		return 1;
	}
	int ins_result = insert_known_links(symlink_path, src_file_name);
	free(src_path);
	src_path = NULL;
	if (ins_result == 0)
	{
		printf("Success!\n");
		return 0;
	} else {
		printf("Failed\n");
		return 1;
	}
}

void status(char *argv[])
{
}

bool eq_str(char *s1, char *s2)
{
	return strcmp(s1, s2) == 0;
}

// Return -1 when unknown command
int conv_cmd_str_id(char *command)
{
	if (eq_str(command, "setup")) return CMD_SETUP;
	if (eq_str(command, "push")) return CMD_PUSH;
	if (eq_str(command, "pull")) return CMD_PULL;
	if (eq_str(command, "commit")) return CMD_COMMIT;
	if (eq_str(command, "manage")) return CMD_MANAGE;
	if (eq_str(command, "unmanage")) return CMD_UNMANAGE;
	if (eq_str(command, "link")) return CMD_LINK;
	if (eq_str(command, "status")) return CMD_STATUS;
	return -1;
}

void init_dirs()
{
	char *app_root = get_app_dir("");
	errno = 0;
	if (mkdir(app_root, S_IRWXU) == -1 && errno != EEXIST)
	{
		char *errstr = errno != 0
			? strerror(errno)
			: "Unknown error";
		error("Failed to create application root directory", errstr);
	}
	char *repo_dir = get_repo_dir_path();
	errno = 0;
	if (mkdir(repo_dir, S_IRWXU) == -1 && errno != EEXIST)
	{
		char *errstr = errno != 0
			? strerror(errno)
			: "Unknown error";
		error("Failed to repository directory", errstr);
	}
	free(app_root);
	app_root = NULL;
	free(repo_dir);
	repo_dir = NULL;
}

int main(int argc, char *argv[])
{
	if (argc < 2 || eq_str(argv[1], "help"))
	{
		usage(argv);
		return 0;
	}
	init_dirs();
	int cmd = conv_cmd_str_id(argv[1]);
	switch (cmd)
	{
		case CMD_SETUP:
			setup(argv);
			break;
		case CMD_MANAGE:
			return manage(argc, argv);
		case CMD_LINK:
			return cmd_link(argc, argv);
		default:
			printf("Unknown command.\n");
			usage(argv);
			return 1;
	}
	return 0;
}
