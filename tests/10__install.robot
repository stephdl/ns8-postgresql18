*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Test Cases ***
Check if postgresql is installed correctly
    # The update scenario has to start from a version a user could be running,
    # so it installs the baseline and reaches the image under test through
    # update-module below.
    IF    '${SCENARIO}' == 'update'
        ${output}  ${rc} =    Execute Command    add-module ${UPDATE_FROM} 1
        ...    return_rc=True
    ELSE
        ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
        ...    return_rc=True
    END
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Global Variable    ${module_id}    ${output.module_id}

Check if postgresql can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"postgresql.domain.org","http2https": true,"lets_encrypt": false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check postgresql path is configured
    ${ocfg} =   Run task    module/${module_id}/get-configuration    {}
    Set Global Variable     ${HOST}    ${ocfg['host']}
    Set Global Variable     ${HTTP2HTTPS}    ${ocfg['http2https']}
    Set Global Variable     ${LE_ENCRYPT}    ${ocfg['lets_encrypt']}
    Should Not Be Empty    ${HOST}
    Should Be True    ${HTTP2HTTPS}
    # Deliberately false: nothing resolves postgresql.domain.org, so the ACME
    # challenge could only fail, and asking Let's Encrypt for a domain this
    # repository does not own is not something CI should do on every push.
    Should Not Be True    ${LE_ENCRYPT}

Seed a probe row before the update
    [Documentation]    Renovate bumps the postgres:18.x tag from time to time:
    ...                same major version, new binary. This is what the update
    ...                scenario actually exercises, and configuration surviving
    ...                it says nothing about data doing the same.
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to seed
    Wait Until Keyword Succeeds    20 times    3 seconds    Postgres accepts connections
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U postgres -c "CREATE TABLE upgrade_probe (id serial primary key, note text); INSERT INTO upgrade_probe (note) VALUES ('pre-upgrade');"
    ...    return_rc=True    return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check if postgresql survives the update
    [Documentation]    Upgrades the baseline installed above to the image under
    ...                test, then reads the configuration and the probe row
    ...                back. A migration that drops either is what this case
    ...                is here to catch. The cases after it then run against
    ...                the upgraded module.
    Skip If    '${SCENARIO}' != 'update'    scenario is ${SCENARIO}, nothing to update
    ${rc} =    Execute Command
    ...    api-cli run update-module --data '{"force":true,"module_url":"${IMAGE_URL}","instances":["${module_id}"]}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0
    ${ocfg} =   Run task    module/${module_id}/get-configuration    {}
    Should Be Equal    ${ocfg['host']}    ${HOST}
    Should Be Equal    ${ocfg['http2https']}    ${HTTP2HTTPS}
    Should Be Equal    ${ocfg['lets_encrypt']}    ${LE_ENCRYPT}
    ${out}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U postgres -tAc "SELECT note FROM upgrade_probe WHERE note='pre-upgrade'"
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${out}    pre-upgrade

*** Keywords ***
Postgres accepts connections
    ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U postgres -tAc 'SELECT 1'
    ...    return_rc=True    return_stdout=False
    Should Be Equal As Integers    ${rc}  0
