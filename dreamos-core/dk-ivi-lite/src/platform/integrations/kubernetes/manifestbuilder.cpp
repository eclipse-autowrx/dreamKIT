// k3s/manifestbuilder.cpp
#include "manifestbuilder.hpp"
#include "../../data/jsonstorage.hpp"
#include <QDir>
#include <QFile>
#include <QTextStream>
#include <QDebug>

using namespace K3s;
using Core::JsonStorage;

static QString writeFile(const QString &fn, const QString &txt)
{
    QFile f(fn);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "ManifestBuilder: cannot write" << fn;
        return {};
    }
    QTextStream(&f) << txt;
    return fn;
}

ManifestInfo ManifestBuilder::write(const AppInfo &app)
{
    ManifestInfo info;
    QString rootDir = DK_CONTAINER_ROOT + "dk_marketplace/";
    info.dir = QString("%1/%2").arg(rootDir, app.id);
    QDir().mkpath(info.dir);

    // ── dashboard JSON ──────────────────────────────────────────────
    info.dashboardJson = QString("%1/%2_dashboard.json")
                             .arg(info.dir, app.id);
    JsonStorage::save(info.dashboardJson,
                      QJsonDocument(app.dashboardConfig.toJson()));

    // ── target / node decision ──────────────────────────────────────
    QString nodeXIP = "xip";
    QString nodeVIP = "vip";
    QString target  = app.dashboardConfig.Target;
    QString node    = (target.isEmpty() || target == nodeXIP)
                        ? nodeXIP : nodeVIP;
    info.isRemoteNode = (node == nodeVIP);
    info.deployNodeName = (info.isRemoteNode ? nodeVIP : nodeXIP);

    qDebug() << "[ManifestBuilder::write] Installing on node:"
             << info.deployNodeName
             << "isRemoteNode:" << info.isRemoteNode;
             
    const QString appId  = app.id;
    const QString image  = app.dashboardConfig.DockerImageURL;

    // ── volume mounts generation ────────────────────────────────────
    QStringList volumeMountLines;
    QStringList volumeLines;
    bool hasAnyVolumes = false;

    auto &rcfg = app.dashboardConfig.RuntimeCfg;
    
    // Check if user explicitly wants host-dev access
    bool needsHostDev = rcfg.contains("hostDev") && rcfg.value("hostDev").toBool();
    if (needsHostDev) {
        hasAnyVolumes = true;
        
        // Ensure /dev exists (should always exist, but just to be safe)
        QString hostDevPath = "/dev";
        if (!QDir(hostDevPath).exists()) {
            qWarning() << "[ManifestBuilder] Host /dev directory does not exist!";
        }
        
        volumeMountLines << QString(
            "        - name: host-dev\n"
            "          mountPath: /dev\n"
            "          readOnly: false");
        
        volumeLines << QString(
            "      - name: host-dev\n"
            "        hostPath:\n"
            "          path: /dev\n"
            "          type: Directory");
        
        qDebug() << "[ManifestBuilder] Adding host-dev mount for app:" << app.id;
    }

    // Process custom volumes from RuntimeCfg
    if (rcfg.contains("volumes")) {
        QJsonArray volumes = rcfg.value("volumes").toArray();
        if (!volumes.isEmpty()) {
            hasAnyVolumes = true;
            info.hasVolumes = true;
        }
        
        for (int i = 0; i < volumes.size(); ++i) {
            QJsonObject vol = volumes[i].toObject();
            QString hostPath = vol.value("hostPath").toString();
            QString mountPath = vol.value("mountPath").toString();
            bool readOnly = vol.value("readOnly").toBool(false);
            
            if (hostPath.isEmpty() || mountPath.isEmpty()) {
                qWarning() << "[ManifestBuilder] Invalid volume config at index" << i 
                          << "- missing hostPath or mountPath";
                continue;
            }
            
            // Create host directory before mounting
            if (!QDir().mkpath(hostPath)) {
                qWarning() << "[ManifestBuilder] Failed to create host directory:" << hostPath;
            } else {
                qDebug() << "[ManifestBuilder] Created host directory:" << hostPath;
            }
            
            QString volumeName = QString("custom-vol-%1").arg(i);
            
            volumeMountLines << QString(
                "        - name: %1\n"
                "          mountPath: %2\n"
                "          readOnly: %3")
                .arg(volumeName, mountPath, readOnly ? "true" : "false");
            
            volumeLines << QString(
                "      - name: %1\n"
                "        hostPath:\n"
                "          path: %2\n"
                "          type: DirectoryOrCreate")
                .arg(volumeName, hostPath);
                
            qDebug() << "[ManifestBuilder] Added volume:" << hostPath << "->" << mountPath 
                     << (readOnly ? "(RO)" : "(RW)");
        }
    }

    // ── environment and args blocks ─────────────────────────────────
    QStringList envLines;
    for (auto it = rcfg.begin(); it != rcfg.end(); ++it) {
        if (it.key() == QLatin1String("node") ||
            it.key() == QLatin1String("args") ||
            it.key() == QLatin1String("volumes") ||
            it.key() == QLatin1String("hostDev"))  // Skip special keys
            continue;
        envLines << QString(
            "            - name: %1\n"
            "              value: \"%2\"")
            .arg(it.key(), it.value().toVariant().toString());
    }
    const QString envBlock = envLines.isEmpty()
                           ? "            # no environment variables"
                           : envLines.join("\n");

    QStringList argLines;
    for (auto v : rcfg.value("args").toArray())
        argLines << QString("           - \"%1\"").arg(v.toString());
    const QString argBlock = argLines.isEmpty()
                           ? "           # no args"
                           : argLines.join("\n");

    // ── deployment yaml template ───────────────────────────────────
    QString deployTpl = R"(apiVersion: apps/v1
kind: Deployment
metadata:
  name: ${name}
  namespace: default
spec:
  replicas: 1
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxUnavailable: 1
      maxSurge: 0
  selector:
    matchLabels:
      app: ${name}
  template:
    metadata:
      labels:
        app: ${name}
    spec:
      nodeSelector:
        kubernetes.io/hostname: ${node}
      hostNetwork: true
      restartPolicy: Always
      terminationGracePeriodSeconds: 60
      
      tolerations:
      - key: "node.kubernetes.io/unreachable"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      - key: "node.kubernetes.io/not-ready"
        operator: "Exists"
        effect: "NoExecute"
        tolerationSeconds: 300
      
      containers:
      - name: ${name}
        image: ${image}
        imagePullPolicy: IfNotPresent
        stdin: true
        tty: true
        
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "1024Mi"
            cpu: "300m"
        
        env:
${env}
${args_section}
        
        securityContext:
          privileged: true
        
${volume_mounts_section}
      
${volumes_section}
)";

    // Generate conditional sections
    QString argsSection;
    if (!argLines.isEmpty()) {
        argsSection = QString("        args:\n%1").arg(argBlock);
    }

    QString volumeMountsSection;
    QString volumesSection; 
    
    // Always add basic tmpfs mounts for containers with read-only filesystems
    QStringList allMounts;
    QStringList allVolumes;
    
    allMounts << QString(
        "        - name: tmp\n"
        "          mountPath: /tmp");
    allMounts << QString(
        "        - name: var-tmp\n"
        "          mountPath: /var/tmp");
    
    allVolumes << QString(
        "      - name: tmp\n"
        "        emptyDir: {}");
    allVolumes << QString(
        "      - name: var-tmp\n"
        "        emptyDir: {}");

    // Add custom volumes if any exist
    if (hasAnyVolumes) {
        allMounts.append(volumeMountLines);
        allVolumes.append(volumeLines);
    }

    volumeMountsSection = QString("        volumeMounts:\n%1").arg(allMounts.join("\n"));
    volumesSection = QString("      volumes:\n%1").arg(allVolumes.join("\n"));

    QString deployYaml = deployTpl
            .replace("${name}",                  appId)
            .replace("${node}",                  node)
            .replace("${image}",                 image)
            .replace("${env}",                   envBlock)
            .replace("${args_section}",          argsSection)
            .replace("${volume_mounts_section}", volumeMountsSection)
            .replace("${volumes_section}",       volumesSection);

    info.deploymentYaml = writeFile(
        QString("%1/%2_deployment.yaml").arg(info.dir, app.id),
        deployYaml);

    // ── pull job yaml ───────────────────────────────────────────────
    static const char *pullTpl = R"(apiVersion: batch/v1
kind: Job
metadata:
  name: pull-${name}
spec:
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/hostname: ${node}
      restartPolicy: Never
      containers:
      - name: pull
        image: ${image}
        imagePullPolicy: Always
        command: ["true"]
)";
    QString pullYaml = QString(pullTpl)
            .replace("${name}",  appId)
            .replace("${node}",  node)
            .replace("${image}", image);

    info.pullJobYaml = writeFile(
        QString("%1/%2_pull.yaml").arg(info.dir, app.id), pullYaml);

    // ── mirror job yaml (only if remote) ────────────────────────────
    if (info.isRemoteNode) {
        const auto parts = image.split('/', Qt::SkipEmptyParts);
        QString rest;
        
        // Check if first part looks like a registry (contains '.' or ':')
        if (parts.size() > 1 && (parts[0].contains('.') || parts[0].contains(':'))) {
            // Has registry prefix, skip it
            rest = parts.mid(1).join('/');
        } else {
            // No registry prefix, keep the whole image name
            rest = image;
        }
        
        const QString mirrorImg = QString("localhost:5000/%1").arg(rest);      

        static const char *mirrorTpl = R"(apiVersion: batch/v1
kind: Job
metadata:
  name: mirror-${name}
spec:
  backoffLimit: 1
  template:
    spec:
      hostNetwork: true
      nodeSelector:
        kubernetes.io/hostname: ${node}
      restartPolicy: Never
      containers:
      - name: mirror
        image: quay.io/containers/skopeo:latest
        command: ["skopeo","copy"]
        args:
          - "--retry-times=3"
          - "--all"
          - "--dest-tls-verify=false"
          - "docker://${src}"
          - "docker://${dst}"
)";
        QString mirrorYaml = QString(mirrorTpl)
                .replace("${name}",  appId)
                .replace("${node}",  nodeXIP)
                .replace("${src}",   image)
                .replace("${dst}",   mirrorImg);
        info.mirrorJobYaml = writeFile(
            QString("%1/%2_mirror.yaml").arg(info.dir, app.id), mirrorYaml);
    }
    
    return info;
}
