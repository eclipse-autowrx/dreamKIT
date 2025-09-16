// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
// core/jsonstorage.hpp
//
// Small utility: load / save a JSON file with automatic directory creation
// and “write-default-if-missing” behaviour.
//
#include <QJsonDocument>
#include <QJsonValue>
#include <QJsonArray>
#include <QJsonObject>

namespace Core {

class JsonStorage final
{
public:
    // If file is missing or unreadable, it will be created with 'def' and
    // that default document is returned.
    static QJsonDocument load(const QString &filePath,
                              QJsonValue    def = QJsonValue(QJsonArray()));

    static bool          save(const QString &filePath,
                              const QJsonDocument &doc);

private:
    JsonStorage() = delete;
};

} // namespace Core
