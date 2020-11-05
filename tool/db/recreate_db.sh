#!/bin/bash

mysql -uroot -p123456 < drop_db.sql
mysql -uroot -p123456 < create_db.sql
mysql -uroot -p123456 -Dgame_s1 < game_tables.sql