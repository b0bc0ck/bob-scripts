# The name of your todofile.
set todofile "scripts/todo.list"
# The name of your channel.
set channel "#" 


bind pub - "!todo" msg_todo

# To DISABLE the timer, uncomment the following line.
# If you have already loaded the script and it is running, you will have to
# find and manually kill the timer (".tcl timers" then ".tcl killtimer #")
#set set_todo_running 1

#-=-=-=-=-=-=-=-=- YOU SHOULD NOT NEED TO EDIT BELOW THIS LINE -=-=-=-=-=-=-=-=-

# These are internal variables and shouldn't be changed here
set todo_ncount -1
set todo_newtodo 0
set todo_lastseen 0
set todo_biggest_ts 0

# Is there any todo?
proc todo_thereistodo {} {
  global todofile 
  if {[todo_count] == 0} {
    return 0
  } else {
    return 1
  }
}

# How many todo items are there?  The first time this is called, it will
# read through the file and set the value of todo_ncount.  In future, the
# value of the variable will be used, rather than reading the file each time.
# Also updates the todo_biggest_ts
proc todo_count {} {
  global todofile todo_ncount todo_biggest_ts channel
  # only ever go through reading the file once -- the first time it's called
  if {$todo_ncount == -1} {
    set todo_ncount 0
    set fd [open $todofile r]
    while {![eof $fd]} {
      set inp [gets $fd]
      if {[eof $fd]} {break}
      if {[string trim $inp " "] == ""} {continue}
      if {[lindex $inp 1] > $todo_biggest_ts} {
        set todo_biggest_ts [lindex $inp 1]
      }
      incr todo_ncount
    }
    close $fd
  } 
  return $todo_ncount
}

# Internal procedure that, given a users handle, tells how many todo items
# there are in the todo file that they haven't read
proc todo_unread {hand} {
  global todofile channel
  set unread 0
  set user_ts [todo_get_ts $hand]
  set fd [open $todofile r]
  while {![eof $fd]} {
    set inp [gets $fd]
    if {[eof $fd]} {break}
    if {[string trim $inp " "] == ""} {continue}
    if {[lindex $inp 1] > $user_ts} {
      incr unread
    }
  }
  close $fd
  return $unread
}

# Internal procedure to print out todo from the file, since it's done more
# than once.  'tochannel' should be 1 if the output is going to a channel, 
# or 0 if it is going privately to a user.  'item' should = 0 if all items
# are to be printed, or a single number to print a specific item.
# If the timestamp is non-zero, only todo items more recent than this
# timestamp are printed.
proc todo_print {tochannel nick item timestamp} {
  global todofile channel
  set next 1
  set fd [open $todofile r]
  while {![eof $fd]} {
    set inp [gets $fd]
    if {[eof $fd]} {break}
    if {[string trim $inp " "] == ""} {continue}
    if {($item == 0) || ($item == $next)} {
      # timestamp == 0 to show all items
      if {[lindex $inp 1] > $timestamp} {  
        set who [lindex $inp 0]
        set date [lrange [ctime [lindex $inp 1]] 0 2]
        set todo [lrange $inp 2 end ]
        # This gets messy because there's four possible cases
        if {$tochannel} {
          if {$item == 0} {
            putserv [format "PRIVMSG %s :%d. \002\(%s\)\002 %s \[%s\]" $channel $next \
                $who $todo $date]
          } else { putserv [format "PRIVMSG %s :\[%s\] %s  \(%s\)" $channel $who \
            $todo $date]
          }
        } else {
          if {$item == 0} {
            putserv [format "NOTICE %s :%d. \[%s\] %s \(%s\)" $channel $next \
                        $who $todo $date]
          } else { putserv [format "NOTICE %s :\[%s\] %s  \(%s\)" $channel $who \
                        $todo $date]
          }
        }
      }
    }
    incr next
  }
  close $fd
  return 1
}

# Get a users "last read" timestamp from the userfile
# Modified in 1.0 to get the timestamp from the 'xtra' field, not the comment
proc todo_get_ts {hand} {
  set xtralist [list [getxtra $hand]]
  set userts [lindex $xtralist [lsearch -glob $xtralist "todo:*"]]
  set have_ts [scan $userts "todo:%d" the_ts]
  if {$have_ts > 0} { 
    return $the_ts
  } else {
    return 0
  }
}

# Set a users "last read" timestamp in the userfile
# Modified in 1.0 to store the timestamp in the 'xtra' field, not the comment
proc todo_set_ts {hand new_ts} {
  set xtralist [list [getxtra $hand]]
  set oldts_idx [lsearch -glob $xtralist "todo:*"]
  # If there was an old timestamp there, delete it
  if {$oldts_idx >= 0} { lreplace $xtralist $oldts_idx $oldts_idx }
  set xtra $hand [join [lappend $xtralist "todo:$new_ts"]]
  return
}


# Add a todo item
proc todo_add {nick uhost hand chan arg} {
  global todofile botnick todo_ncount todo_newtodo todo_biggest_ts channel
  
  set message [lrange $arg 1 end]
  if {$message == ""} {
    putserv "PRIVMSG $channel :  Usage: !todo add <your todo item...>"
    putserv "PRIVMSG $channel :  adds something to the todo file"
    return 0
  }
  set fd [open $todofile a]
  puts $fd [format "%s %s %s" $nick [unixtime] $message]
  close $fd
  # Do not just use 'incr' in case todo_count currently = -1
  set todo_ncount [expr [todo_count] + 1]
  set todo_newtodo 1
  set todo_biggest_ts [unixtime]
  putserv "PRIVMSG $channel :Added to the todo file, thanks!"
  return 1
}

# Delete a todo item
proc todo_del {nick uhost hand chan arg} {
  global todofile botnick todo_ncount channel
  
  set otherargs [lrange $arg 1 end]
  if {[scan $otherargs "%d" which] != 1} {
    todo_help $nick $uhost $hand $arg ; return 0 }
  if {($which < 1) || ($which > [todo_count])} {
    putserv "PRIVMSG $channel :The item number must be between 1 and [todo_count]"
    return 0
  }
  # We will copy the entries from the original file to a temp file, except
  # for the one to be deleted, then rename the temp file to be the original.
  # This is how eggdrop deletes notes, so we will use it too.
  set next 1
  set fd [open $todofile r]
  set newfd [open "${todofile}new" w]
  while {![eof $fd]} {
    set inp [gets $fd]
    if {[eof $fd]} {break}
    if {[string trim $inp " "] == ""} {continue}
    set who [lindex $inp 0]
    if {$next == $which} {
      # Can only delete your own todo unless you're a master
      if {$who==""} {
        putserv "PRIVMSG $channel :You can\'t delete other people\'s todo!"
        puts $newfd $inp
      } else {
        # delete it -- ie, do not copy it -- just update the counter
        # Do not use 'incr' just in case it = -1
        set todo_ncount [expr [todo_count] - 1]
      }
    } else {
      puts $newfd $inp
    }
    incr next
  }
  close $fd
  close $newfd
  file delete $todofile
  file rename ${todofile}new $todofile
  putserv "PRIVMSG $channel :Deleted from the todo file, thanks!"
  return 1
}


# Read the channel todo privately
proc todo_read {nick uhost hand chan arg} {
  global todofile botnick todo_biggest_ts channel
  if {[todo_thereistodo]} {
      todo_print 1 $nick 0 0
  } else {
    putserv "PRIVMSG $channel :Sorry, there is no todo at the moment!"
  }
  putserv "PRIVMSG $channel : For help with other todo commands, \002!todo help\002"
  return 1
}  

# Reset the counter associated with the todo file.
proc todo_reset {nick uhost hand channel arg} {
  global todo_ncount todo_biggest_ts
  
  # Just reset the counter, don't touch the file
  set todo_ncount -1
  set todo_biggest_ts 0
  putserv "PRIVMSG $channel :OK, reset."
  return 1
}

# Erase all entries in the todo file
proc todo_clear {nick uhost hand channel arg} {
  global todofile todo_ncount todo_newtodo
  set fd [open $todofile w]
  puts $fd " "
  close $fd
  set todo_ncount -1
  set todo_newtodo 0
  putserv "PRIVMSG $channel :Okay, todo file cleared!"
  return 1
}

# Display some help
proc todo_help {nick uhost hand channel arg} {
  putserv "PRIVMSG $channel :Usage: \002!todo add <your todo item>\002 | \002!todo delete #\002 | \002!todo read\002"
}

# The main binding - does the dispatching of requests
proc msg_todo {nick uhost hand chan arg} {
  global channel
  switch [string tolower [lindex $arg 0]] {
    "add"       {set r [todo_add $nick $uhost $hand $channel $arg]}
    ""          {set r [todo_read $nick $uhost $hand $channel $arg]}
    "help"      {set r [todo_help $nick $uhost $hand $channel $arg]}
    "new"       {set r [todo_add $nick $uhost $hand $channel $arg]}
    "del"       {set r [todo_del $nick $uhost $hand $channel $arg]}
    "delete"    {set r [todo_del $nick $uhost $hand $channel $arg]}
    "erase"     {set r [todo_del $nick $uhost $hand $channel $arg]}
    "read"      {set r [todo_read $nick $uhost $hand $channel $arg]}
    "reset"     {set r [todo_reset $nick $uhost $hand $channel $arg]}
    "clear"     {set r [todo_clear $nick $uhost $hand $channel $arg]}
    default     {set r [todo_help $nick $uhost $hand $channel $arg]}
    
  }
  return $r
}

putlog "todo.tcl script loaded successfully!"
