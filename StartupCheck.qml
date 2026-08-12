import QtQuick
import qs.Common

QtObject {
    function check(done) {
        Proc.runCommand("fedsrv.check", ["curl", "-s", "-m", "2", "http://10.190.217.209:61208/api/widget/information"], function(stdout, exitCode) {
            if (exitCode === 0 && stdout.trim().length > 0) {
                done(null);
            } else {
                done({
                    "title": "Server Inaccessible",
                    "details": "Could not connect to http://10.190.217.209:61208.\nEnsure main.py is running on the VM/Server."
                });
            }
        });
    }
}
