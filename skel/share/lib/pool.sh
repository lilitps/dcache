# Useful functions for working with pools
#
# Relies on the functions in utils.sh, config.sh and
# services.sh. These must be loaded prior to calling any of the
# following functions.

getPoolSetting() # in $1 = pool path, in $2 = key, out $3 = value
{
    local path
    local key

    path=$1
    key=$2

    if [ ! -f "${path}/setup" ]; then
        printp "Setup file not found in $1" 1>&2
        exit 4
    fi

    #                    Comments      Trailing space  Print value
    #                    vvvvvvvv      vvvvvvv         vvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvvv
    eval $3=$(sed -n -e 's/#.*$//' -e 's/[  ]*$//' -e "s/^[         ]*${key}[       ]*\(.*\)/\1/p" "${path}/setup")
}

# Extracts the size of a pool in GiB.
getSizeOfPool() # in $1 = pool path, out $2 = size
{
    local diskspace
    getPoolSetting "$1" "set max diskspace" diskspace
    stringToGiB "$diskspace" $2
}

printPoolConfig() # $1 = path, $2 = name, $3 = domain, $4 = optional size, $5 = optional meta, $6 = optional lfs
{
    local path
    local name
    local domain
    local size
    local meta
    local lfs

    path="$1"
    name="$2"
    domain="$3"
    size="$4"
    meta="$5"
    lfs="$6"

    echo "[$domain/pool]"
    echo "name=$name"
    echo "path=$path"
    if [ -n "$size" ]; then
        echo "maxDiskSpace=$size"
    fi
    case "$meta" in
        file)
            echo "metaDataRepository=org.dcache.pool.repository.meta.file.FileMetaDataRepository"
            echo "waitForFiles=\${path}/data:\${path}/control"
            ;;
        db)
            echo "metaDataRepository=org.dcache.pool.repository.meta.db.BerkeleyDBMetaDataRepository"
            echo "waitForFiles=\${path}/data:\${path}/meta"
            ;;
        *)
            echo "waitForFiles=\${path}/data"
            ;;
    esac

    if [ -n "$lfs" ]; then
        echo "lfs=$lfs"
    fi
}

createPool() # $1 = path, $2 = name, $3 = domain, $4 = optional size, $5 = optional meta, $6 = optional lfs
{
    local path
    local name
    local domain
    local size
    local meta
    local lfs

    local bytes
    local ds
    local parent
    local user
    local layout

    path="$1"
    name="$2"
    domain="$3"
    size="$4"
    meta="$5"
    lfs="$6"

    # Path must not exist
    if [ -e "${path}" ]; then
        fail 1 "${path} already exists. Operation aborted."
    fi

    # Make sure the parent path exists
    parent=$(dirname "${path}")
    if [ ! -d "${parent}" ]; then
        mkdir -p "${parent}" || fail 1 "Failed to create $parent"
    fi

    # Create directories
    mkdir -p "${path}" "${path}/data" ||
    fail 1 "Failed to create directory tree"
    case "$meta" in
        file)
            mkdir "${path}/control" ||
            fail 1 "Failed to create directory tree"
            ;;
        db)
            mkdir "${path}/meta" ||
            fail 1 "Failed to create directory tree"
            ;;
        ?*)
            fail 1 "Unknown meta data format: $meta"
            ;;
        *)
            ;;
    esac

    # Warn the user if the file system doesn't contain enough free
    # space. We only generate a warning since the user may choose to
    # mount another file system below the pool directory.
    if [ -n "$size" ]; then
        ds=$(getFreeSpace "${parent}")
        stringToGiB "$size" bytes
        if [ "${ds}" -lt "${bytes}" ]; then
            printp "WARNING: Pool size of ${bytes} GiB exceeds available
                space. ${path} only has ${ds} GiB of free space."
        fi
    fi

    # Set ownership of pool directories
    if contains "$domain" $(getProperty dcache.domains); then
        user="$(getProperty dcache.user "$domain")"
    else
        user="$(getProperty dcache.user)"
    fi
    if [ -n "$user" ]; then
        chown -R "$user" "$path"
    fi

    layout="$(getProperty dcache.layout.uri)"
    case "${layout}" in
        file:*)
            (
                echo
                if ! contains "$domain" $(getProperty dcache.domains); then
                    echo "[$domain]"
                fi
                printPoolConfig "$@"
            ) >> "${layout#file:}"
            printp "Created a pool in $path. The pool was added to
                    $domain in $layout."
            ;;
        *)
            printp "Created a pool in $path. The pool cannot be used until
                    it has been added to a domain. Add the following to the
                    layout file, ${layout}, to do so:" \
                   "$(printPoolConfig "$@")"
            ;;
    esac
}

# Reconstruct the meta data Berkeley DB of a pool
reconstructMeta() # in $1 = src meta dir, in $2 = dst meta dir
{
    local src
    local dst
    local dump
    local load
    local databases
    local classpath

    src="$1"
    dst="$2"
    classpath="$(getProperty dcache.paths.classpath)"
    databases="java_class_catalog state_store storage_info_store"

    for db in ${databases}; do
        CLASSPATH="${classpath}" ${JAVA} com.sleepycat.je.util.DbDump \
              -h "$src" -r -d "$dst" -v -s $db || return
    done

    for db in ${databases}; do
        CLASSPATH="${classpath}" ${JAVA} com.sleepycat.je.util.DbLoad \
              -f "${dst}/${db}.dump" -h "$dst" -s $db || return
        rm "${dst}/${db}.dump"
    done
}

# Check prerequisites
require sed dirname rm
