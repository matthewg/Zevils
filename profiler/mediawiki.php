<?php
  /**
   * Provides authentication for the RPG Web Profiler system using the
   * mediawiki
   */
  global $FORUM_ROOT, $DB;

  // PhpBB variables need a global scope
  global $mediawiki_root_path;
  global $phpEx;
  global $starttime;
  
  global $db;

  global $board_config;
  global $theme;
  global $images;
  global $lang;
  global $nav_links;
  global $gen_simple_header;

  # Initialise common code
  $mediaWiki = new MediaWiki();

  function authenticate(&$sid) {
    global $FORUM_ROOT, $mediaWiki;
    global $TABLE_USERS, $rpgDB;
      
    //ini_set("include_path", "/home/mattsachs/wiki.zevils.com/includes:/home/mattsachs/wiki.zevils.com:" . ini_get("include_path"));

    $user = User::newFromSession();
    $user->load();
    if(!$user or !$_SESSION['wsUserName']) return false;
  
    $sid->_sid = $_SESSION['wsToken'];
    $sid->_username = mysql_escape_string($_SESSION['wsUserName']);
    $sid->_email = $user->getEmail();
    $sid->_ip = $_SERVER['REMOTE_ADDR'];

    // Attempt to retrieve the user session details from the db.
    $sql = sprintf("SELECT iplog, slength, dm FROM %s WHERE pname = '%s'",
            $TABLE_USERS, $sid->_username);
    $res = $rpgDB->query($sql);
    if (!$res) {
      $err = $rpgDB->error();
      __printFatalErr("Failed to query database: " . $err['message'] . "\n" . $sql, __LINE__, __FILE__);
    }
    if ($rpgDB->num_rows() == 1) {
      // Record the user data.
      $row = $rpgDB->fetch_row($res);
      $sid->_iplog = unserialize(stripslashes($row['iplog']));
      $sid->_slength = $row['slength'];
      $sid->_dm = $row['dm'] == 'Y';
    } else {
      create_user($sid->_username);
    
      $sid->_iplog = "";
      $sid->_slength = 180;
      $sid->_dm = false;
    }
    
    return true;
  }
    
      function create_user($username) {
    
        global $TABLE_USERS, $rpgDB;
    
        $sql = sprintf("INSERT INTO %s (pname, slength, dm) VALUES ('%s', %d, 'N')", $TABLE_USERS,
                        $username, 180);
        $res = $rpgDB->query($sql);
    
        if( !$res ) {
          __printFatalErr("Unable to create new user profile: " . $username . '\n' . $rpgDB->error());
        }
    
      }
    
    ?>
    