CREATE TABLE log_daemon (
  log_id int(10) unsigned NOT NULL auto_increment,
  time datetime NOT NULL default '0000-00-00 00:00:00',
  data varchar(255) NOT NULL default '',
  PRIMARY KEY  (log_id)
);

CREATE TABLE log_ext (
  log_id int(10) unsigned NOT NULL auto_increment,
  extension varchar(5) NOT NULL default '',
  event enum('auth','getwakes','setpin','delcookie','forgotpin') NOT NULL default 'auth',
  result enum('success','failure') default NULL,
  start_time datetime NOT NULL default '0000-00-00 00:00:00',
  end_time datetime NOT NULL default '0000-00-00 00:00:00',
  data varchar(255) default NULL,
  phoneline varchar(255) default NULL,
  ip varchar(15) default NULL,
  PRIMARY KEY  (log_id),
  KEY extension (extension),
  KEY event (event),
  KEY result (result),
  KEY start_time (start_time)
);

CREATE TABLE log_wake (
  log_id int(10) unsigned NOT NULL auto_increment,
  wake_id int(10) unsigned NOT NULL default '0',
  extension varchar(5) NOT NULL default '',
  event enum('create','delete','edit','activate') NOT NULL default 'create',
  result enum('success','failure') default NULL,
  start_time datetime NOT NULL default '0000-00-00 00:00:00',
  end_time datetime default NULL,
  data varchar(255) default NULL,
  phoneline varchar(255) default NULL,
  ip varchar(15) default NULL,
  PRIMARY KEY  (log_id),
  KEY extension (extension),
  KEY wake_id (wake_id),
  KEY event (event),
  KEY result (result),
  KEY start_time (start_time)
);

CREATE TABLE prefs (
  extension varchar(5) NOT NULL default '',
  pin varchar(4) default NULL,
  forgot_pin tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (extension)
);

CREATE TABLE wakes (
  wake_id int(10) unsigned NOT NULL auto_increment,
  extension char(5) NOT NULL default '',
  time time NOT NULL default '00:00:00',
  message int(11) NOT NULL default '0',
  date date default NULL,
  weekdays set('Mon','Tue','Wed','Thu','Fri','Sat','Sun') default NULL,
  cal_type set('normal','holidays','Brandeis') default NULL,
  snooze_count int(11) NOT NULL default '0',
  trigger_date date default NULL,
  trigger_snooze int(11) default NULL,
  next_trigger datetime default NULL,
  disabled tinyint(1) NOT NULL default '0',
  PRIMARY KEY  (wake_id),
  KEY time (time),
  KEY date (date),
  KEY weekdays (weekdays),
  KEY next_trigger (next_trigger),
  KEY extension (extension)
);
