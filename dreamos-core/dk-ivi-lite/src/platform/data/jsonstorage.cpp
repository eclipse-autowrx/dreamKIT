// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "jsonstorage.hpp"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QDebug>

using namespace Core;

static QJsonDocument _toDoc(QJsonValue v)
{
    return v.isArray() ? QJsonDocument(v.toArray())
                       : QJsonDocument(v.toObject());
}

QJsonDocument JsonStorage::load(const QString &filePath, QJsonValue def)
{
    QFileInfo fi(filePath);
    QDir().mkpath(fi.path());

    if (!fi.exists()) {
        save(filePath, _toDoc(def));
        return _toDoc(def);
    }

    QFile f(filePath);
    if (!f.open(QIODevice::ReadOnly)) {
        qWarning() << "JsonStorage::load: cannot open" << filePath;
        return _toDoc(def);
    }
    auto doc = QJsonDocument::fromJson(f.readAll());
    if (doc.isNull()) {
        qWarning() << "JsonStorage::load: invalid JSON in" << filePath;
        return _toDoc(def);
    }
    return doc;
}

bool JsonStorage::save(const QString &filePath, const QJsonDocument &doc)
{
    QFileInfo fi(filePath);
    QDir().mkpath(fi.path());

    QFile f(filePath);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "JsonStorage::save: cannot write" << filePath;
        return false;
    }
    f.write(doc.toJson(QJsonDocument::Indented));
    return true;
}
