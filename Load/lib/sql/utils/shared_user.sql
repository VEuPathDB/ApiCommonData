create or replace package SHARED_USER as
procedure get_session_info;
procedure get_all_session_info;
procedure get_all_session_info_full;
procedure kill_session( p_sid in number, p_serial in number );
end SHARED_USER;

/

show errors

create or replace package body SHARED_USER as
procedure get_session_info
is
begin
  for i in ( select s.sid, s.serial#, s.osuser, s.username, s.status,
                   s.logon_time, vs.last_active_time, substr(vs.sql_text,1,80) sql_text1,
                   substr(vs.sql_text,81,80) sql_text2,
                   substr(vs.sql_text,161,80) sql_text3,
                   substr(vs.sql_text,241,80) sql_text4,
                   substr(vs.sql_text,321,80) sql_text5,
                   substr(vs.sql_text,401,80) sql_text6,
                   substr(vs.sql_text,481,80) sql_text7
            from v$session s, v$sql vs, v$process vp
            where s.sql_address = vs.address
              and s.sql_hash_value = vs.hash_value
              and vs.users_executing > 0
              and s.paddr = vp.addr
              and s.username <> 'DBSNMP'
              and s.username <> 'STRMADMIN'
              and s.username <> 'SYS'
              and s.username <> 'SYSMAN'
              and s.username <> 'SYSTEM')
        loop
                        if not (substr(i.sql_text1,1,33) = 'SELECT S.SID, S.SERIAL#, S.OSUSER') then
           dbms_output.put_line('p_sid=' || i.sid);
           dbms_output.put_line('p_serial#=' || i.serial#);
           dbms_output.put_line('osuser=' || i.osuser);
           dbms_output.put_line('username=' || i.username);
           dbms_output.put_line('status=' || i.status);
           dbms_output.put_line('logon_time=' || i.logon_time);
           dbms_output.put_line('last_active_time=' || i.last_active_time);
           dbms_output.put_line('kill_command="execute sys_shared.SHARED_USER.kill_session(' || i.sid || ', ' || i.serial# || ')"');
           dbms_output.put_line('sql_text:');
           dbms_output.put_line(i.sql_text1);
           dbms_output.put_line(i.sql_text2);
           dbms_output.put_line(i.sql_text3);
           dbms_output.put_line(i.sql_text4);
           dbms_output.put_line(i.sql_text5);
           dbms_output.put_line(i.sql_text6);
           dbms_output.put_line(i.sql_text7);
           dbms_output.put_line('------------------------------------------------');
                        end if;
        end loop;
end;

procedure get_all_session_info
is
begin
  for i in ( select s.sid, s.serial#, s.osuser, s.username, s.status,
                   s.logon_time, vs.last_active_time, s.module,
                   substr(vs.sql_text,1,80) sql_text1,
                   substr(vs.sql_text,81,80) sql_text2,
                   substr(vs.sql_text,161,80) sql_text3,
                   substr(vs.sql_text,241,80) sql_text4,
                   substr(vs.sql_text,321,80) sql_text5,
                   substr(vs.sql_text,401,80) sql_text6,
                   substr(vs.sql_text,481,80) sql_text7
            from v$session s, v$sql vs, v$process vp
            where s.sql_address = vs.address (+)
              and s.sql_hash_value = vs.hash_value (+)
              and s.paddr = vp.addr
              and s.TYPE = 'USER'
              and s.username <> 'DBSNMP'
              and s.username <> 'STRMADMIN'
              and s.username <> 'SYS'
              and s.username <> 'SYSMAN'
              and s.username <> 'SYSTEM')
        loop
                        if not (substr(i.sql_text1,1,33) = 'SELECT S.SID, S.SERIAL#, S.OSUSER') then
           dbms_output.put_line('p_sid=' || i.sid);
           dbms_output.put_line('p_serial#=' || i.serial#);
           dbms_output.put_line('osuser=' || i.osuser);
           dbms_output.put_line('username=' || i.username);
           dbms_output.put_line('status=' || i.status);
           dbms_output.put_line('logon_time=' || i.logon_time);
           dbms_output.put_line('last_active_time=' || i.last_active_time);
           dbms_output.put_line('module=' || i.module);
           dbms_output.put_line('kill_command="execute sys_shared.SHARED_USER.kill_session(' || i.sid || ', ' || i.serial# || ')"');
           dbms_output.put_line('sql_text:');
           dbms_output.put_line(i.sql_text1);
           dbms_output.put_line(i.sql_text2);
           dbms_output.put_line(i.sql_text3);
           dbms_output.put_line(i.sql_text4);
           dbms_output.put_line(i.sql_text5);
           dbms_output.put_line(i.sql_text6);
           dbms_output.put_line(i.sql_text7);
           dbms_output.put_line('------------------------------------------------');
                        end if;
        end loop;
end;

procedure get_all_session_info_full
is
begin
  for i in (select s.sid, s.serial#, s.osuser, s.username, s.status,
                   s.logon_time, vs.last_active_time, s.module,
                   vs.sql_fulltext, vs.sql_text
            from v$session s, v$sql vs, v$process vp
            where s.sql_address = vs.address (+)
              and s.sql_hash_value = vs.hash_value (+)
              and s.paddr = vp.addr
              and s.TYPE = 'USER'
              and s.username <> 'DBSNMP'
              and s.username <> 'STRMADMIN'
              and s.username <> 'SYS'
              and s.username <> 'SYSMAN'
              and s.username <> 'SYSTEM')
        loop
                        if not (substr(i.sql_text,1,33) = 'SELECT S.SID, S.SERIAL#, S.OSUSER') then
           dbms_output.put_line('p_sid=' || i.sid);
           dbms_output.put_line('p_serial#=' || i.serial#);
           dbms_output.put_line('osuser=' || i.osuser);
           dbms_output.put_line('username=' || i.username);
           dbms_output.put_line('status=' || i.status);
           dbms_output.put_line('logon_time=' || i.logon_time);
           dbms_output.put_line('last_active_time=' || i.last_active_time);
           dbms_output.put_line('module=' || i.module);
           dbms_output.put_line('kill_command="execute sys_shared.SHARED_USER.kill_session(' || i.sid || ', ' || i.serial# || ')"');
           dbms_output.put_line('sql_fulltext:');
           dbms_output.put_line(i.sql_fulltext);
           dbms_output.put_line('------------------------------------------------');
                        end if;
        end loop;
end;

procedure kill_session( p_sid in number, p_serial in number )
is
   lv_user varchar2(30);
begin
   select username into lv_user from v$session where sid = p_sid and serial# = p_serial;

   if lv_user is not null and lv_user = USER then
      execute immediate 'alter system kill session ''' || p_sid || ',' || p_serial || '''';
   else
      raise_application_error(-20000,'Attempt to kill other user''s session has been blocked.');
   end if;
end;

end SHARED_USER;

/

show errors

GRANT execute ON SHARED_USER TO public;
