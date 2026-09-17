*** Settings ***
Library    SSHLibrary

*** Test Cases ***
Check if posgresql works as expected
    Wait Until Keyword Succeeds    20 times    3 seconds    Ping postgresql

Check if the database answers
    # pgAdmin serving its login page says nothing about the engine behind it.
    # The container may still be coming up when the page already answers, so
    # the case waits, and names what it sees when it gives up.
    ${containers}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman ps --format '{{.Names}}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${containers}    postgresql-app    Containers of the module: ${containers}
    ${version} =    Wait Until Keyword Succeeds    60s    5s    Postgres reports its version
    Should Contain    ${version}    PostgreSQL 18

Check if the generated secret is readable only by the module
    # bin/create-secrets writes it with umask 266, so 0400
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'stat -c %a $AGENT_STATE_DIR/secrets/passwords.env; grep -c POSTGRES_PASSWORD $AGENT_STATE_DIR/secrets/passwords.env'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    400
    ${env}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'cat $AGENT_STATE_DIR/environment'
    ...    return_rc=True
    Should Not Contain    ${env}    POSTGRES_PASSWORD

Check if the database dump is consistent
    # bin/module-dump-state is what Restic backs up: state-include.conf lists
    # state/postgresql.pg_dump
    ${output}  ${err}  ${rc} =    Execute Command    runagent -m ${module_id} module-dump-state
    ...    return_rc=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0    module-dump-state failed: ${err}
    ${output}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} bash -c 'head -5 $AGENT_STATE_DIR/postgresql.pg_dump; wc -c < $AGENT_STATE_DIR/postgresql.pg_dump'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${output}    PostgreSQL database cluster dump

Check if the services are running
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} systemctl --user is-active postgresql.service postgresql-app.service pgadmin-app.service
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if a configuration without the host is refused
    # The agent exits 10 on a JSON Schema input validation failure
    ${errors}  ${rc} =    Execute Command
    ...    api-cli run module/${module_id}/configure-module --data '{"http2https":true,"lets_encrypt":false}'
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  10
    # A missing required field is reported on the whole object, and the field
    # name goes to stderr, which Execute Command does not return here
    Should Contain    ${errors}    (root)_required

*** Keywords ***
Postgres reports its version
    ${output}  ${err}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U postgres -tAc 'SELECT version()'
    ...    return_rc=True    return_stderr=True
    Should Be Equal As Integers    ${rc}  0    psql exited ${rc}: ${err}
    RETURN    ${output}

Ping postgresql
    ${out}  ${err}  ${rc} =    Execute Command    curl -k -f -H 'Host: postgresql.domain.org' https://127.0.0.1/login
    ...    return_rc=True  return_stdout=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${out}    <title>pgAdmin
