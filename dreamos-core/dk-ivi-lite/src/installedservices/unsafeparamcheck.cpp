#include <QCoreApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QFile>
#include <QProcess>
#include <QDebug>
#include <QStringList>
#include <QRegularExpression>
#include <QFileInfo>

// Function to check if a parameter is unsafe
bool isUnsafeParameter(const QString& param) {
    // List of known harmful or potentially unsafe Docker options
    const QStringList unsafeOptions = {
        "-v", "--volume",             // Volume mounts
        "--privileged",               // Privileged mode
        "--network",                  // Network mode, including --network host
        "-p", "--publish",            // Port mappings
        "--cap-add", "--cap-drop",    // Capability modifications
        "--mount",                    // Advanced mount options
        "--add-host",                 // Modify /etc/hosts
        "--pid",                      // PID namespace sharing
        "--ipc",                      // IPC namespace sharing
        "--security-opt"              // Security options
        // Add more unsafe options as needed
    };

    // Check if the parameter matches any of the unsafe options
    for (const QString& unsafe : unsafeOptions) {
        if (param == unsafe || param.startsWith(unsafe + "=")) {
            return true;
        }
    }
    return false;
}

// Function to validate the device path is within "/dev"
bool isValidDevicePath(const QString& deviceArg) {
    // Check if the device argument contains '..'
    if (deviceArg.contains("..")) {
        qDebug() << "Device path contains '..', which is not allowed:" << deviceArg;
        return false;
    }

    // Split the device argument on colon ':'
    QStringList paths = deviceArg.split(":", Qt::SkipEmptyParts);

    if (paths.isEmpty()) {
        return false;
    }

    // The first part is the host path
    QString hostPath = paths[0];

    // Check if the device path starts with "/dev/"
    if (!hostPath.startsWith("/dev/")) {
        qDebug() << "Invalid device path (must start with /dev):" << deviceArg;
        return false;
    }

    // If both checks pass, the device path is considered valid
    qDebug() << "Device path is valid:" << deviceArg;

    return true;
}

// Function to build a safe Docker command
QStringList buildSafeDockerParams(const QJsonObject& jsonConfig) {
    QStringList commandArgs;
    // commandArgs << "docker" << "run";

    // Process "run_params" field
    if (jsonConfig.contains("run_params")) {
        QString runParams = jsonConfig["run_params"].toString();

        // Split the parameters respecting quotes and escape sequences
        QRegularExpression regex(R"((?:"[^"]*"|'[^']*'|[^\s]+))");
        QRegularExpressionMatchIterator i = regex.globalMatch(runParams);

        QStringList paramsList;
        while (i.hasNext()) {
            QRegularExpressionMatch match = i.next();
            paramsList << match.captured(0);
        }

        // Iterate over the params list
        int idx = 0;
        while (idx < paramsList.size()) {
            QString param = paramsList[idx];

            // Check if parameter is unsafe
            if (isUnsafeParameter(param)) {
                qDebug() << "Omitting unsafe parameter:" << param;

                // Skip argument if the option requires one and it's not in the "--option=value" format
                if (!param.contains("=") && idx + 1 < paramsList.size() && !paramsList[idx + 1].startsWith("-")) {
                    qDebug() << "Omitting unsafe argument:" << paramsList[idx + 1];
                    idx += 2; // Skip the option and its argument
                } else {
                    idx += 1; // Skip the option
                }
                continue;
            }

            // Special handling for --device option
            if (param == "--device") {
                // Expecting an argument
                if (idx + 1 < paramsList.size()) {
                    QString deviceArg = paramsList[idx + 1];

                    // Validate the device path
                    if (isValidDevicePath(deviceArg)) {
                        commandArgs << param << deviceArg;
                        qDebug() << "Adding allowed device option:" << param << deviceArg;
                    } else {
                        qDebug() << "Invalid device path (must be within /dev):" << deviceArg;
                    }

                    idx += 2; // Move past the option and its argument
                } else {
                    qDebug() << "Missing argument for" << param;
                    idx += 1; // Move past the option
                }
                continue;
            }

            // For other safe parameters, just add them
            commandArgs << param;
            idx += 1;
        }
    }

    return commandArgs;
}

QString getSafeDockerParam(QString runtimecfgFile) {
    // Load JSON configuration
    QFile file(runtimecfgFile);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning("Couldn't open runtimecfgFile file.");
        return "";
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(file.readAll());
    if (jsonDoc.isNull()) {
        qWarning("Invalid JSON format.");
        return "";
    }
    QJsonObject jsonConfig = jsonDoc.object();

    // Build the safe Docker command
    QStringList safeParamList = buildSafeDockerParams(jsonConfig);
    QString safeParam = " " + safeParamList.join(' ') + " ";
    qDebug() << "Docker params: " << safeParam;

    return safeParam;
}

QString getAudioParam(QString runtimecfgFile) {
    // Load JSON configuration
    QFile file(runtimecfgFile);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning("Couldn't open runtimecfgFile file.");
        return "";
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(file.readAll());
    if (jsonDoc.isNull()) {
        qWarning("Invalid JSON format.");
        return "";
    }
    QJsonObject jsonConfig = jsonDoc.object();

    QString dkUsername = qgetenv("DK_USER");
    QString rootHomeDir = "/home/" + dkUsername;

    // Build the safe Docker command
    // Process "run_params" field
    if (jsonConfig.contains("audio_params")) {
        QString runParams = jsonConfig["audio_params"].toString();
        if (runParams == "yes") {
            QString audioParams = " --device /dev/snd --group-add audio -e PULSE_SERVER=unix:${XDG_RUNTIME_DIR}/pulse/native -v ${XDG_RUNTIME_DIR}/pulse/native:${XDG_RUNTIME_DIR}/pulse/native -v " + rootHomeDir + "/.config/pulse/cookie:/root/.config/pulse/cookie ";
            qDebug() << "audio_params : " << audioParams;
            return audioParams;
        }
        else {
            qDebug() << "audio_params : " << runParams;
        }
    }

    qDebug() << "audio_params : isn't defined.";
    return "";
}

QString getUiParam(QString runtimecfgFile) {
    // Load JSON configuration
    QFile file(runtimecfgFile);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning("Couldn't open runtimecfgFile file.");
        return "";
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(file.readAll());
    if (jsonDoc.isNull()) {
        qWarning("Invalid JSON format.");
        return "";
    }
    QJsonObject jsonConfig = jsonDoc.object();

    // Build the safe Docker command
    // Process "run_params" field
    if (jsonConfig.contains("ui_params")) {
        QString runParams = jsonConfig["ui_params"].toString();
        if (runParams == "yes") {
            // -v /tmp/.X11-unix:/tmp/.X11-unix -e DISPLAY=:0 --device /dev/dri:/dev/dri 
            QString uiParams = " -v /tmp/.X11-unix:/tmp/.X11-unix ";
            qDebug() << "uiParams : " << uiParams;
            return uiParams;
        }
        else {
            qDebug() << "uiParams : " << runParams;
        }
    }

    qDebug() << "uiParams : isn't defined.";
    return "";
}

QString getSpecialParam(QString runtimecfgFile) {
    // Load JSON configuration
    QFile file(runtimecfgFile);
    if (!file.open(QIODevice::ReadOnly)) {
        qWarning("Couldn't open runtimecfgFile file.");
        return "";
    }

    QJsonDocument jsonDoc = QJsonDocument::fromJson(file.readAll());
    if (jsonDoc.isNull()) {
        qWarning("Invalid JSON format.");
        return "";
    }
    QJsonObject jsonConfig = jsonDoc.object();

    // Build the safe Docker command
    // Process "run_params" field
    if (jsonConfig.contains("special_params")) {
        QString runParams = jsonConfig["special_params"].toString();
        if (runParams == "network_bypass") {
            QString specialParams = " --network host ";
            qDebug() << "specialParams : " << specialParams;
            return specialParams;
        }
        else {
            qDebug() << "specialParams : " << runParams;
        }
    }

    qDebug() << "specialParams : isn't defined.";
    return "";
}

