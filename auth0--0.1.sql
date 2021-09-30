-- complain if script is sourced in psql, rather than via CREATE EXTENSION
\echo Use "CREATE EXTENSION auth0" to load this file. \quit


-- Get config
CREATE FUNCTION auth0.get_config(key text) RETURNS text
    LANGUAGE sql STABLE
    AS $_$

  WITH auth0_config AS (
    --- From https://github.com/PostgREST/postgrest/blob/main/src/PostgREST/Config/Database.hs
    with
      role_setting as (
        select setdatabase, unnest(setconfig) as setting from pg_catalog.pg_db_role_setting
        where setrole = current_user::regrole::oid
          and setdatabase in (0, (select oid from pg_catalog.pg_database where datname = current_catalog))
      ),
      kv_settings as (
        select setdatabase, split_part(setting, '=', 1) as k, split_part(setting, '=', 2) as value from role_setting
        where setting like 'auth0.%'
      )
      select distinct on (key) replace(k, 'auth0.', '') as key, value
      from kv_settings
      order by key, setdatabase desc;
  )

  SELECT "value" FROM auth0_config WHERE "key"=$1;
$_$;

COMMENT ON FUNCTION auth0.get_config(key text) IS 'Get value from auth0 customized option from current role';

-- Set config
CREATE FUNCTION auth0.set_config(_key text, _value text) RETURNS void
    LANGUAGE plpgsql
    AS $_$
  BEGIN
    EXECUTE format('ALTER ROLE %I SET auth0.%s TO %L', current_user, _key, _value);
  END;
$_$;

COMMENT ON FUNCTION auth0.set_config(_key text, _value text) IS 'Set value of auth0 customized option to current role';

-- Get API token
CREATE FUNCTION auth0.get_api_token() RETURNS text
    LANGUAGE plpgsql
    AS $$
DECLARE
	api_token text;
	res_body json;
	res_status integer;
	auth0_domain text;
	req_url text;
	req_body text;
	token_expiration timestamp;
BEGIN
	IF auth0.get_config('api_token') = ''
		OR CAST(auth0.get_config('api_token_expires_at') AS timestamp) < CURRENT_TIMESTAMP THEN
		-- GET new token from Authentication API
		RAISE NOTICE 'Getting new token';
		auth0_domain = auth0.get_config('domain');
		req_url = format('https://%s/oauth/token', auth0_domain);
		req_body = format('audience=%s&grant_type=client_credentials&client_id=%s&client_secret=%s',
						  urlencode(format('https://%s/api/v2/', auth0_domain)),
						  auth0.get_config('client_id'),
						  auth0.get_config('client_secret'));
		SELECT status, content FROM http_post(req_url, req_body, 'application/x-www-form-urlencoded')
			INTO res_status, res_body;
        IF res_status != 200 THEN
			RAISE 'Error while retrieving token: %', res_body::text;
			RETURN NULL;
		END IF;

		token_expiration = CURRENT_TIMESTAMP + CAST(format('%s seconds', res_body->>'expires_in') AS Interval);
		PERFORM auth0.set_config('api_token', res_body->>'access_token');
		PERFORM auth0.set_config('api_token_expires_at', token_expiration::text);
	END IF;
	RETURN auth0.get_config('api_token');
END;
$$;

COMMENT ON FUNCTION auth0.get_api_token() IS 'Get management API token from authentication API with app credentials';

-- Get user
CREATE FUNCTION auth0.get_user(userid text, fields text) RETURNS json
    LANGUAGE sql
    AS $$
SELECT content::json FROM http((
	'GET',
	'https://' || auth0.get_config('domain') || '/api/v2/users/' || userid || '?fields=' || fields,
	ARRAY[http_header('Authorization', 'Bearer '|| auth0.get_api_token())],
	'',
	'')::http_request);
$$;

-- Get user by email
CREATE FUNCTION auth0.get_user_by_email(email text, fields text) RETURNS json
    LANGUAGE sql
    AS $$
SELECT content::json FROM http((
	'GET',
	'https://' || auth0.get_config('domain') || '/api/v2/users-by-email/?fields=' || urlencode(fields)||'&email='||urlencode(lower(email)),
	ARRAY[http_header('Authorization', 'Bearer '|| auth0.get_api_token())],
	'',
	'')::http_request);
$$;

-- Update user
CREATE FUNCTION auth0.update_user(userid text, params json) RETURNS record
    LANGUAGE sql
    AS $$
SELECT status, content::json->>'user_id' AS user_id FROM http((
	'PATCH',
	'https://' || auth0.get_config('domain') || '/api/v2/users/' || userid,
	ARRAY[http_header('Authorization', 'Bearer '|| auth0.get_api_token())],
	'application/json',
	params)::http_request);
$$;


-- Create user
CREATE FUNCTION auth0.create_user(params json) RETURNS record
    LANGUAGE sql
    AS $_$
SELECT status, content::json->>'user_id' AS user_id FROM http((
	'POST',
	'https://' || auth0.get_config('domain') || '/api/v2/users',
	ARRAY[http_header('Authorization', 'Bearer '|| auth0.get_api_token())],
	'application/json',
	$1)::http_request);
$_$;


CREATE FUNCTION auth0.change_password_prompt(email text) RETURNS void
    LANGUAGE plpgsql
    AS $$
DECLARE
	res_body text;
	res_status integer;
	auth0_domain text;
	req_url text;
	req_body json;
BEGIN
	auth0_domain = auth0.get_config('domain');
	req_url = format('https://%s/dbconnections/change_password', auth0_domain);
	req_body = json_build_object(
		'client_id', auth0.get_config('client_id'),
		'email', email,
		'connection', auth0.get_config('connection')
	);
	SELECT status, content FROM http_post(req_url, req_body::text, 'application/json')
		INTO res_status, res_body;
	IF res_status != 200 THEN
		RAISE 'Error while triggering change password email prompt: % - %', res_status, res_body::text;
		RETURN;
	END IF;
	RETURN;
END;
$$;

