-- create gbrowse_sessions table to store gbrowse session data 
-- instead of using text file

create table gbrowse_sessions
(
  id        char(32)  not null primary key, 
  a_session long      not null           
);
