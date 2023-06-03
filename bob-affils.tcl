# vim: set shiftwidth=4 smarttab expandtab:

bind pub - "!affils" list_affils

set bobaffils "/home/ftpd/glftpd/bin/bob-affils.sh"

proc list_affils {nick uhost hand chan arg} {
    global bobaffils
    exec $bobaffils list &
}
