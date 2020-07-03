#!/usr/bin/env lucicfg
# https://chromium.googlesource.com/infra/luci/luci-go/+/master/lucicfg/doc/

"""LUCI project configuration for libyuv CQ and CI."""

lucicfg.check_version("1.15.0")

lucicfg.config(
    lint_checks = ["default"],
    config_dir = ".",
    tracked_files = [
        "commit-queue.cfg",
        "cr-buildbucket.cfg",
        "luci-logdog.cfg",
        "luci-milo.cfg",
        "luci-scheduler.cfg",
        "project.cfg",
    ],
)

luci.project(
    name = "libyuv",
    buildbucket = "cr-buildbucket.appspot.com",
    logdog = "luci-logdog.appspot.com",
    milo = "luci-milo.appspot.com",
    notify = "luci-notify.appspot.com",
    scheduler = "luci-scheduler.appspot.com",
    swarming = "chromium-swarm.appspot.com",
    acls = [
        acl.entry(acl.PROJECT_CONFIGS_READER, groups = ["all"]),
        acl.entry(acl.LOGDOG_READER, groups = ["all"]),
        acl.entry(acl.LOGDOG_WRITER, groups = ["luci-logdog-chromium-writers"]),
        acl.entry(acl.SCHEDULER_READER, groups = ["all"]),
        acl.entry(acl.SCHEDULER_OWNER, groups = ["project-libyuv-admins"]),
        acl.entry(acl.BUILDBUCKET_READER, groups = ["all"]),
    ],
)

luci.logdog(
    gs_bucket = "chromium-luci-logdog",
)

luci.milo(
    logo = "https://storage.googleapis.com/chrome-infra-public/logo/libyuv-logo.png",
)

luci.gitiles_poller(
    name = "master-gitiles-trigger",
    bucket = "ci",
    repo = "https://chromium.googlesource.com/libyuv/libyuv",
)

# Milo views
def libyuv_ci_view(name, category, short_name):
    return luci.console_view_entry(
        console_view = "main",
        builder = name,
        category = category,
        short_name = short_name,
    )

def libyuv_try_view(name):
    return luci.list_view_entry(
        list_view = "try",
        builder = name,
    )

luci.console_view(
    name = "main",
    title = "libyuv Main Console",
    include_experimental_builds = True,
    repo = "https://chromium.googlesource.com/libyuv/libyuv/",
)

luci.list_view(
    name = "cron",
    title = "Cron",
    entries = ["DEPS Autoroller"],
)

luci.list_view(
    name = "try",
    title = "libyuv Try Builders",
)

# Commit queue
def libyuv_try_job_verifier(name, cq_group, experiment_percentage):
    return luci.cq_tryjob_verifier(
        builder = name,
        cq_group = cq_group,
        experiment_percentage = experiment_percentage,
    )

luci.cq(
    status_host = "chromium-cq-status.appspot.com",
    submit_max_burst = 4,
    submit_burst_delay = 8 * time.minute,
)

luci.cq_group(
    name = "master",
    watch = [
        cq.refset(
            repo = "https://chromium-review.googlesource.com/libyuv/libyuv",
            refs = ["refs/heads/master"],
        ),
    ],
    acls = [
        acl.entry(acl.CQ_COMMITTER, groups = ["project-libyuv-committers"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups = ["project-libyuv-tryjob-access"]),
    ],
    retry_config = cq.RETRY_ALL_FAILURES,
    cancel_stale_tryjobs = True,
)

luci.cq_group(
    name = "config",
    watch = [
        cq.refset(
            repo = "https://chromium-review.googlesource.com/libyuv/libyuv",
            refs = ["refs/heads/infra/config"],
        ),
    ],
    acls = [
        acl.entry(acl.CQ_COMMITTER, groups = ["project-libyuv-committers"]),
        acl.entry(acl.CQ_DRY_RUNNER, groups = ["project-libyuv-tryjob-access"]),
    ],
    retry_config = cq.RETRY_ALL_FAILURES,
    cancel_stale_tryjobs = True,
)

# Buckets
luci.bucket(
    name = "ci",
    acls = [
        acl.entry(acl.BUILDBUCKET_OWNER, groups = [
            "project-libyuv-admins",
        ]),
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users = [
            "luci-scheduler@appspot.gserviceaccount.com",
        ]),
    ],
)
luci.bucket(
    name = "try",
    acls = [
        acl.entry(acl.BUILDBUCKET_OWNER, groups = [
            "project-libyuv-admins",
        ]),
        acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = [
            "project-libyuv-tryjob-access",
            "service-account-cq",
        ]),
    ],
)
luci.bucket(
    name = "cron",
    acls = [
        acl.entry(acl.BUILDBUCKET_OWNER, groups = [
            "project-libyuv-admins",
        ]),
        acl.entry(acl.BUILDBUCKET_TRIGGERER, users = [
            "luci-scheduler@appspot.gserviceaccount.com",
        ]),
    ],
)
luci.bucket(
    name = "master.tryserver.libyuv",
    acls = [
        acl.entry(acl.BUILDBUCKET_OWNER, users = [
            "libyuv@chrome-infra-auth.iam.gserviceaccount.com",
        ]),
        acl.entry(acl.BUILDBUCKET_TRIGGERER, groups = [
            "project-libyuv-tryjob-access",
        ]),
    ],
)

# Builders
def libyuv_ci_builder(name, dimensions, properties, triggered_by):
    return luci.builder(
        name = name,
        dimensions = dimensions,
        properties = properties,
        bucket = "ci",
        service_account = "libyuv-ci-builder@chops-service-accounts.iam.gserviceaccount.com",
        triggered_by = triggered_by,
        swarming_tags = ["vpython:native-python-wrapper"],
        execution_timeout = 180 * time.minute,
        build_numbers = True,
        executable = luci.recipe(
            name = "libyuv/libyuv",
            cipd_package = "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build",
        ),
    )

def libyuv_try_builder(name, dimensions, properties, recipe_name = "libyuv/libyuv"):
    return luci.builder(
        name = name,
        dimensions = dimensions,
        properties = properties,
        bucket = "try",
        service_account = "libyuv-try-builder@chops-service-accounts.iam.gserviceaccount.com",
        swarming_tags = ["vpython:native-python-wrapper"],
        execution_timeout = 180 * time.minute,
        build_numbers = True,
        executable = luci.recipe(
            name = recipe_name,
            cipd_package = "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build",
        ),
    )

def ci_builder(name, os, category, short_name = None):
    dimensions = {"pool": "luci.flex.ci"}
    properties = {
        "mastername": "client.libyuv",
        "$build/goma": {
            "server_host": "goma.chromium.org",
            "use_luci_auth": True,
        },
    }
    if os == "android":
        dimensions.update({"device_type": "bullhead"})
        triggered_by = ["Android Debug"]
    if os == "mac":
        dimensions.update({"os": "Mac-10.13", "cpu": "x86-64"})
        triggered_by = ["master-gitiles-trigger"]
    elif os == "win":
        dimensions.update({"os": "Windows-10", "cores": "8", "cpu": "x86-64"})
        properties["$build/goma"].update({"enable_ats": True})
        triggered_by = ["master-gitiles-trigger"]
    elif os == "linux":
        dimensions.update({"os": "Ubuntu-16.04", "cores": "8", "cpu": "x86-64"})
        properties["$build/goma"].update({"enable_ats": True})
        triggered_by = ["master-gitiles-trigger"]

    libyuv_ci_view(name, category, short_name)
    return libyuv_ci_builder(name, dimensions, properties, triggered_by)

def try_builder(name, os, experiment_percentage = None):
    dimensions = {"pool": "luci.flex.try"}
    properties = {
        "mastername": "tryserver.libyuv",
        "$build/goma": {
            "server_host": "goma.chromium.org",
            "use_luci_auth": True,
        },
    }
    if os == "android":
        dimensions.update({"device_type": "bullhead"})
    if os == "mac":
        dimensions.update({"os": "Mac-10.13", "cpu": "x86-64"})
    elif os == "win":
        dimensions.update({"os": "Windows-10", "cores": "8", "cpu": "x86-64"})
        properties["$build/goma"].update({"enable_ats": True})
    elif os == "linux":
        dimensions.update({"os": "Ubuntu-16.04", "cores": "8", "cpu": "x86-64"})
        properties["$build/goma"].update({"enable_ats": True})

    if name == "presubmit":
        recipe_name = "run_presubmit"
        properties.update({"repo_name": "libyuv", "runhooks": True})
        libyuv_try_job_verifier(name, "config", experiment_percentage)
        return libyuv_try_builder(name, dimensions, properties, recipe_name)

    libyuv_try_job_verifier(name, "master", experiment_percentage)
    libyuv_try_view(name)
    return libyuv_try_builder(name, dimensions, properties)

luci.builder(
    name = "DEPS Autoroller",
    bucket = "cron",
    service_account = "libyuv-ci-autoroll-builder@chops-service-accounts.iam.gserviceaccount.com",
    dimensions = {
        "pool": "luci.webrtc.cron",
        "os": "Linux",
        "cpu": "x86-64",
    },
    swarming_tags = ["vpython:native-python-wrapper"],
    execution_timeout = 120 * time.minute,
    build_numbers = True,
    schedule = "0 14 * * *",  # Every 2 hours.
    executable = luci.recipe(
        name = "libyuv/roll_deps",
        cipd_package = "infra/recipe_bundles/chromium.googlesource.com/chromium/tools/build",
    ),
)

ci_builder("Android ARM64 Debug", "linux", "Android|Builder", "dbg")
ci_builder("Android Debug", "linux", "Android|Builder", "dbg")
ci_builder("Android Release", "linux", "Android|Builder", "rel")
ci_builder("Android32 x86 Debug", "linux", "Android|Builder|x86", "dbg")
ci_builder("Android64 x64 Debug", "linux", "Android|Builder|x64", "dbg")
ci_builder("Android Tester ARM32 Debug (Nexus 5X)", "android", "Android|Tester|ARM 32", "dbg")
ci_builder("Android Tester ARM32 Release (Nexus 5X)", "android", "Android|Tester|ARM 32", "rel")
ci_builder("Android Tester ARM64 Debug (Nexus 5X)", "android", "Android|Tester|ARM 64", "dbg")

ci_builder("Linux Asan", "linux", "Linux", "asan")
ci_builder("Linux MSan", "linux", "Linux", "msan")
ci_builder("Linux Tsan v2", "linux", "Linux", "tsan")
ci_builder("Linux UBSan", "linux", "Linux|UBSan")
ci_builder("Linux UBSan vptr", "linux", "Linux|UBSan", "vptr")
ci_builder("Linux32 Debug", "linux", "Linux|32", "dbg")
ci_builder("Linux32 Release", "linux", "Linux|32", "rel")
ci_builder("Linux64 Debug", "linux", "Linux|64", "dbg")
ci_builder("Linux64 Release", "linux", "Linux|64", "rel")

ci_builder("Mac Asan", "mac", "Mac", "asan")
ci_builder("Mac64 Debug", "mac", "Mac", "dbg")
ci_builder("Mac64 Release", "mac", "Mac", "rel")

ci_builder("Win32 Debug", "win", "Win|32|Debug")
ci_builder("Win32 Debug (Clang)", "win", "Win|32|Debug", "clg")
ci_builder("Win32 Release", "win", "Win|32|Release")
ci_builder("Win32 Release (Clang)", "win", "Win|32|Release", "clg")
ci_builder("Win64 Debug", "win", "Win|64|Debug", "clg")
ci_builder("Win64 Debug (Clang)", "win", "Win|64|Debug", "clg")
ci_builder("Win64 Release", "win", "Win|64|Release")
ci_builder("Win64 Release (Clang)", "win", "Win|64|Release", "clg")

ci_builder("iOS ARM64 Debug", "mac", "iOS|ARM64", "dbg")
ci_builder("iOS ARM64 Release", "mac", "iOS|ARM64", "rel")
ci_builder("iOS Debug", "mac", "iOS", "dbg")
ci_builder("iOS Release", "mac", "iOS", "rel")

try_builder("android", "android")
try_builder("android_arm64", "android")
try_builder("android_rel", "android")
try_builder("android_x64", "linux")
try_builder("android_x86", "linux")
try_builder("ios", "mac")
try_builder("ios_arm64", "mac")
try_builder("ios_arm64_rel", "mac")
try_builder("ios_rel", "mac")

try_builder("linux", "linux")
try_builder("linux_asan", "linux")
try_builder("linux_gcc", "linux", experiment_percentage = 100)
try_builder("linux_msan", "linux")
try_builder("linux_rel", "linux")
try_builder("linux_tsan2", "linux")
try_builder("linux_ubsan", "linux")
try_builder("linux_ubsan_vptr", "linux")
try_builder("mac", "mac")
try_builder("mac_asan", "mac")
try_builder("mac_rel", "mac")
try_builder("win", "win")
try_builder("win_clang", "win")
try_builder("win_clang_rel", "win")
try_builder("win_rel", "win")
try_builder("win_x64_clang_rel", "win")
try_builder("win_x64_rel", "win")
try_builder("presubmit", "linux")
