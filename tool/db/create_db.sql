create schema `game_s1` default character set utf8 collate utf8_general_ci;
grant select,insert,update,delete,create,drop,alter,lock tables on `game_s1`.* to 'root'@'%' identified by '123456';
grant select,insert,update,delete,create,drop,alter,lock tables on `game_s1`.* to 'root'@'localhost' identified by '123456';