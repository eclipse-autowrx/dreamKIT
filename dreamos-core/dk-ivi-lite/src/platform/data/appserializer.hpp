// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
// core/appserializer.hpp
//
// Pure conversion helpers:  AppInfo <-> QJsonObject / QJsonArray
//
#include "datamanager.hpp"     // supplies struct AppInfo
#include <QJsonArray>

namespace Core {

class AppSerializer
{
public:
    static AppInfo        fromJson(const QJsonObject &o);
    static QJsonObject    toJson(const AppInfo &app);
    static QList<AppInfo> listFromJson(const QJsonArray &arr);
};

} // namespace Core
