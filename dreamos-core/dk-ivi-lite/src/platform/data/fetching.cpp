// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "fetching.hpp"

#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>    
#include <QUrl>
#include <QUrlQuery>
#include <QJsonDocument>      
#include <QJsonObject>        
#include <QJsonArray>         
#include <QEventLoop>
#include <QFile>
#include <QDir>
#include <QDebug>

QString marketplace_login(const QString &login_url,
                          const QString &username,
                          const QString &password)
{
    QNetworkAccessManager mgr;
    // use brace‐init to avoid vexing‐parse
    QNetworkRequest req{ QUrl(login_url) };
    req.setHeader(QNetworkRequest::ContentTypeHeader,
                  "application/json");

    QJsonObject j;
    j["email"]    = username;
    j["password"] = password;

    QEventLoop loop;
    auto *r = mgr.post(req, QJsonDocument(j).toJson());
    QObject::connect(r, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    QString token;
    if (r->error() == QNetworkReply::NoError) {
        auto resp = QJsonDocument::fromJson(r->readAll()).object();
        token = resp.value("token").toString();
        qDebug() << "Login token:" << token;
    } else {
        qWarning() << "Login error:" << r->errorString();
    }
    r->deleteLater();
    return token;
}

bool queryMarketplacePackages(const QString &marketplace_url,
                              const QString &token,
                              int page, int limit,
                              const QString &category)
{
    QNetworkAccessManager mgr;
    QUrlQuery q;
    q.addQueryItem("page",     QString::number(page));
    q.addQueryItem("limit",    QString::number(limit));
    q.addQueryItem("category", category);

    qDebug() << "Login marketplace_url:" << marketplace_url;
    QUrl url(marketplace_url + "/package");
    url.setQuery(q);
    QNetworkRequest req{ url };
    if (!token.isEmpty())
        req.setRawHeader("Authorization",
                         "Bearer " + token.toUtf8());

    QEventLoop loop;
    auto *r = mgr.get(req);
    QObject::connect(r, &QNetworkReply::finished, &loop, &QEventLoop::quit);
    loop.exec();

    if (r->error() != QNetworkReply::NoError) {
        qWarning() << "Fetch error:" << r->errorString();
        r->deleteLater();
        return false;
    }

    auto doc = QJsonDocument::fromJson(r->readAll());
    r->deleteLater();
    if (!doc.isObject()) {
        qWarning() << "Fetch: invalid JSON";
        return false;
    }

    // dump raw data[] to disk
    QJsonArray arr = doc.object().value("data").toArray();
    QString folder = QDir::cleanPath(
        QLatin1String(qgetenv("DK_CONTAINER_ROOT")) +
        "/dk_marketplace");
    QDir().mkpath(folder);
    QString fn = folder + "/marketplace_data_installcfg.json";
    QFile f(fn);
    if (!f.open(QIODevice::WriteOnly)) {
        qWarning() << "Cannot write raw data to" << fn;
        return false;
    }
    f.write(QJsonDocument(arr).toJson(QJsonDocument::Indented));
    f.close();
    return true;
}
