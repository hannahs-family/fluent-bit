from invoke import task

ARCHITECTURES = [
    "arm32v7",
    "arm64v8",
]

LIB_ARCHITECTURES = {
    "arm32v7": "arm-linux-gnueabihf",
    "arm64v8": "aarch64-linux-gnu"
}

DOCKER_REPOSITORY = "hannahsfamily/fluent-bit"

STABLE_VERSION = "1.2.0"

ADDITIONAL_MANIFEST_REPOS = ["fluent/fluent-bit"]


@task(iterable=["architectures"])
def build(c,
          version=STABLE_VERSION,
          architectures=[],
          repository=DOCKER_REPOSITORY):
    if len(architectures) == 0:
        architectures = ARCHITECTURES.copy()

    major, minor, patch = version.split(".")

    tag = "{}:{}-$TARGET".format(repository, version)
    cmd = [
        "docker", "build", "-t", tag, "--build-arg", "\"target=$TARGET\"",
        "--build-arg", "\"lib_target=$LIB_TARGET\"", "--build-arg",
        "\"FLB_VERSION={}\"".format(version), "--build-arg",
        "\"FLB_MAJOR={}\"".format(major), "--build-arg",
        "\"FLB_MINOR={}\"".format(minor), "--build-arg",
        "\"FLB_PATCH={}\"".format(patch), "."
    ]

    for target in architectures:
        env = {"TARGET": target, "LIB_TARGET": LIB_ARCHITECTURES[target]}
        c.run(" ".join(cmd), env=env, pty=True)


@task(iterable=["architectures"])
def push(c,
         version=STABLE_VERSION,
         architectures=[],
         repository=DOCKER_REPOSITORY):
    if len(architectures) == 0:
        architectures = ARCHITECTURES.copy()

    cmd = ["docker", "push"]

    for target in architectures:
        c.run(" ".join([*cmd, "{}:{}-{}".format(repository, version, target)]),
              pty=True)


@task(iterable=["architectures"])
def manifest(c,
             version=STABLE_VERSION,
             tag=None,
             architectures=[],
             repository=DOCKER_REPOSITORY):
    if len(architectures) == 0:
        architectures = ARCHITECTURES.copy()

    if tag is None:
        tag = version

    cmd = ["docker", "manifest", "create", "{}:{}".format(repository, tag)]
    cmd.extend("{}:{}-{}".format(repository, version, target)
               for target in architectures)
    cmd.extend("{}:{}".format(repo, tag) for repo in ADDITIONAL_MANIFEST_REPOS)
    c.run(" ".join(cmd), pty=True)
    c.run("docker manifest push --purge {}:{}".format(repository, tag),
          pty=True)
