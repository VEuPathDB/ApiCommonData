-- delete guest-user accounts that have been been inactive for 48 hours
prompt user_roles
delete from userlogins3.user_roles
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt strategies
delete from userlogins3.strategies
where root_step_id in (select s.display_id
                  from userlogins3.users u, userlogins3.steps s
                  where u.user_id = s.user_id
                    and u.email like 'WDK_GUEST_%'
                    and u.last_active < trunc(sysdate) - 2);

prompt steps
delete from userlogins3.steps
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt preferences
delete from userlogins3.preferences
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt user_datasets
delete from userlogins3.user_datasets
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt user_datasets2
delete from userlogins3.user_datasets2
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt histories
delete from userlogins3.histories
where user_id in (select user_id
                  from userlogins3.users
                  where email like 'WDK_GUEST_%'
                    and last_active < trunc(sysdate) - 2);

prompt users
delete from userlogins3.users
where email like 'WDK_GUEST_%'
  and last_active < trunc(sysdate) - 2;


-- exit
