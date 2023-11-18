# vim: set shiftwidth=4 smarttab expandtab:

bind pub - "!affils" list_affils

set bobaffils "/opt/ftpd/glftpd/bin/bob-affils.sh"

proc list_affils {nick uhost hand chan arg} {
    global bobaffils

    # list affils with sections
    set data [exec $bobaffils list]
    # list affils only
    #set data [exec $bobaffils]

    foreach line [split $data "\n"] {
        putserv "PRIVMSG $chan :$line"
    }
}

putlog "bob-affils.tcl loaded!"
