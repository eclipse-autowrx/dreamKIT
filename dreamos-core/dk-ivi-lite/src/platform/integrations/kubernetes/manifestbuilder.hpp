// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
// k3s/manifestbuilder.hpp
//
// Emits dashboard JSON + deployment / pull / mirror job YAML files.
//
#include "../../data/datamanager.hpp"
#include <QString>

namespace K3s {

struct ManifestInfo
{
    QString dir;               // <root>/<appId> - for manifests
    QString dataDir;           // <root>/<appId>_data - only created if volumes needed
    QString dashboardJson;
    QString deploymentYaml;
    QString pullJobYaml;
    QString mirrorJobYaml;
    QString deployNodeName = "xip";
    bool    isRemoteNode = false;
    bool    hasVolumes = false;    // indicates if custom volumes were configured
};

class ManifestBuilder
{
public:
    // rootDir == “…/dk_marketplace”
    static ManifestInfo write(const AppInfo &app);
};

} // namespace K3s
