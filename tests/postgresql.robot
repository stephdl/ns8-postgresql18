*** Settings ***
Library    SSHLibrary
Resource    api.resource

*** Variables ***
${CLUSTER_USER}     admin
${CLUSTER_PASSWORD}    Nethesis,1234

*** Test Cases ***
Check if postgresql is installed correctly
    ${output}  ${rc} =    Execute Command    add-module ${IMAGE_URL} 1
    ...    return_rc=True
    Should Be Equal As Integers    ${rc}  0
    &{output} =    Evaluate    ${output}
    Set Suite Variable    ${module_id}    ${output.module_id}

Check if postgresql can be configured
    ${rc} =    Execute Command    api-cli run module/${module_id}/configure-module --data '{"host":"postgresql.domain.org","http2https": true,"lets_encrypt": false}'
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

Check postgresql path is configured
    ${ocfg} =   Run task    module/${module_id}/get-configuration    {}
    Set Suite Variable     ${HOST}    ${ocfg['host']}
    Set Suite Variable     ${HTTP2HTTPS}    ${ocfg['http2https']}
    Set Suite Variable     ${LE_ENCRYPT}    ${ocfg['lets_encrypt']}
    Should Not Be Empty    ${HOST}
    Should Be True    ${HTTP2HTTPS}
    # Deliberately false: nothing resolves postgresql.domain.org, so the ACME
    # challenge could only fail, and asking Let's Encrypt for a domain this
    # repository does not own is not something CI should do on every push.
    Should Not Be True    ${LE_ENCRYPT}

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

Take screenshots of the module pages
    [Documentation]    Capture what cluster-admin shows, for the software center
    ...                entry. Tagged ui: the shared runner skips it unless
    ...                RUN_UI_TESTS is true, since it needs a browser.
    [Tags]    ui
    Import Library    Browser
    New Browser    chromium    headless=True
    New Context    ignoreHTTPSErrors=True    viewport={'width': 1280, 'height': 900}
    Login to cluster-admin
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}
    Wait For Elements State    iframe >>> h2 >> text="Status"    visible    timeout=10s
    # The page fills itself from several tasks: let them land
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/1._Status.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=settings
    Wait For Elements State    iframe >>> h2 >> text="Settings"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/2._Settings.png
    Go To    https://${NODE_ADDR}/cluster-admin/#/apps/${module_id}?page=about
    Wait For Elements State    iframe >>> h2 >> text="About"    visible    timeout=10s
    Sleep    5s
    Take Screenshot    filename=${OUTPUT DIR}/browser/screenshot/3._About.png
    Close Browser

Check if postgresql is removed correctly
    ${rc} =    Execute Command    remove-module --no-preserve ${module_id}
    ...    return_rc=True  return_stdout=False
    Should Be Equal As Integers    ${rc}  0

*** Keywords ***
Postgres reports its version
    ${output}  ${err}  ${rc} =    Execute Command
    ...    runagent -m ${module_id} podman exec postgresql-app psql -U postgres -tAc 'SELECT version()'
    ...    return_rc=True    return_stderr=True
    Should Be Equal As Integers    ${rc}  0    psql exited ${rc}: ${err}
    RETURN    ${output}

Login to cluster-admin
    New Page    https://${NODE_ADDR}/cluster-admin/
    Fill Text    text="Username"    ${CLUSTER_USER}
    Click    button >> text="Continue"
    Fill Text    text="Password"    ${CLUSTER_PASSWORD}
    Click    button >> text="Log in"
    Wait For Elements State    css=#main-content    visible    timeout=10s

Ping postgresql
    ${out}  ${err}  ${rc} =    Execute Command    curl -k -f -H 'Host: postgresql.domain.org' https://127.0.0.1/login
    ...    return_rc=True  return_stdout=True  return_stderr=True
    Should Be Equal As Integers    ${rc}  0
    Should Contain    ${out}    <title>pgAdmin
