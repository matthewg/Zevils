#!/bin/bash

if [ "$1" == "" ]
	then echo "Usage: nntp.sh slash-db"
else \
	mysqldump -c -t -u root -p -- "$1" stories > /tmp/stories.sql
	echo "DELETE FROM stories; \
	ALTER TABLE sections ADD COLUMN cdate timestamp(14); \
	ALTER TABLE topics ADD COLUMN cdate timestamp(14); \
	ALTER TABLE stories ADD COLUMN snum mediumint(8) UNSIGNED NOT NULL; \
	ALTER TABLE stories ADD KEY snum (snum); \
	ALTER TABLE stories CHANGE COLUMN snum snum mediumint(8) UNSIGNED NOT NULL auto_increment; \
	" | mysql -u root -p -- "$1"
	mysql -u root -p -- "$1" < /tmp/stories.sql
fi
