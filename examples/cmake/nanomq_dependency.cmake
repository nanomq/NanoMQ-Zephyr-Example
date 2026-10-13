# Locate the nanomq checkout the examples build against.
#
# The examples no longer live inside the nanomq repository.  nanomq — which
# carries the NanoNNG fork as its `nng/` submodule — is fetched as a local
# dependency of this repository by scripts/fetch-nanomq.sh, pinned to the
# revision recorded in nanomq.ref.
#
# Usage from a demo CMakeLists.txt:
#   include(../cmake/nanomq_dependency.cmake)
#
# Defines:
#   NANOMQ_ROOT  cache PATH, defaults to <repo>/extern/nanomq; override with
#                -DNANOMQ_ROOT=/path/to/nanomq to build against any checkout
#                (e.g. a worktree where you edited the nng sources)
#   NNG_ROOT     NANOMQ_ROOT/nng, the NanoNNG fork

set(NANOMQ_ROOT "${CMAKE_CURRENT_LIST_DIR}/../../extern/nanomq"
    CACHE PATH "nanomq checkout used by the examples (holds nanomq/ and the nng/ submodule)")

if(NOT EXISTS "${NANOMQ_ROOT}/nanomq/nanomq.c")
  message(FATAL_ERROR
    "no nanomq checkout at ${NANOMQ_ROOT}\n"
    "Fetch the pinned revision with:  scripts/fetch-nanomq.sh\n"
    "or build against an existing checkout:  -DNANOMQ_ROOT=/path/to/nanomq")
endif()

set(NNG_ROOT "${NANOMQ_ROOT}/nng")
if(NOT EXISTS "${NNG_ROOT}/include/nng/nng.h")
  message(FATAL_ERROR
    "the nanomq checkout at ${NANOMQ_ROOT} has no nng/ submodule content\n"
    "Initialize it with:  git -C ${NANOMQ_ROOT} submodule update --init nng")
endif()
