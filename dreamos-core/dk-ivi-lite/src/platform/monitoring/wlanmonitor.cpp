// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#include "wlanmonitor.hpp"
#include "../notifications/notificationmanager.hpp"
#include <QDebug>

WlanMonitor::WlanMonitor(QObject *parent)
    : QObject(parent)
    , m_checkTimer(new QTimer(this))
    , m_networkManager(new QNetworkAccessManager(this))
    , m_currentReply(nullptr)
    , m_status(Status::Unknown)
    , m_currentUrlIndex(0)
    , m_checkInterval(DEFAULT_CHECK_INTERVAL)
    , m_timeout(DEFAULT_TIMEOUT)
{
    // Set default test URLs
    m_testUrls = {
        "http://www.google.com",
        // "http://httpbin.org/get",
        // "http://www.cloudflare.com"
    };
    
    // Configure timer
    m_checkTimer->setSingleShot(false);
    connect(m_checkTimer, &QTimer::timeout,
            this, &WlanMonitor::performConnectivityCheck);
    
    // Configure network manager
    // connect(m_networkManager, &QNetworkAccessManager::finished,
    //         this, &WlanMonitor::onNetworkReplyFinished);
}

WlanMonitor::~WlanMonitor()
{
    stopMonitoring();
}

void WlanMonitor::setCheckInterval(int milliseconds)
{
    if (milliseconds <= 0) {
        qWarning() << "[WlanMonitor] Invalid check interval:" << milliseconds;
        return;
    }
    
    m_checkInterval = milliseconds;
    if (m_checkTimer->isActive()) {
        m_checkTimer->setInterval(m_checkInterval);
    }
}

int WlanMonitor::checkInterval() const
{
    return m_checkInterval;
}

void WlanMonitor::setTestUrls(const QStringList &urls)
{
    if (urls.isEmpty()) {
        qWarning() << "[WlanMonitor] Cannot set empty URL list";
        return;
    }
    
    m_testUrls = urls;
    m_currentUrlIndex = 0;
    qDebug() << "[WlanMonitor] Updated test URLs to:" << m_testUrls;
}

QStringList WlanMonitor::testUrls() const
{
    return m_testUrls;
}

void WlanMonitor::setTimeout(int milliseconds)
{
    if (milliseconds <= 0) {
        qWarning() << "[WlanMonitor] Invalid timeout:" << milliseconds;
        return;
    }
    
    m_timeout = milliseconds;
}

int WlanMonitor::timeout() const
{
    return m_timeout;
}

void WlanMonitor::startMonitoring()
{
    if (m_checkTimer->isActive()) {
        qDebug() << "[WlanMonitor] Monitoring already active";
        return;
    }
    
    qDebug() << "[WlanMonitor] Starting connectivity monitoring every" 
             << m_checkInterval << "ms";
    
    m_checkTimer->setInterval(m_checkInterval);
    m_checkTimer->start();
    
    // Perform initial check
    checkConnectionNow();
}

void WlanMonitor::stopMonitoring()
{
    if (!m_checkTimer->isActive()) {
        qDebug() << "[WlanMonitor] Monitoring already stopped";
        return;
    }
    
    qDebug() << "[WlanMonitor] Stopping connectivity monitoring";
    m_checkTimer->stop();
    
    // Cancel any ongoing request
    if (m_currentReply) {
        m_currentReply->abort();
        m_currentReply->deleteLater();
        m_currentReply = nullptr;
    }
}

void WlanMonitor::checkConnectionNow()
{
    performConnectivityCheck();
}

void WlanMonitor::performConnectivityCheck()
{
    // Don't start new check if one is already in progress
    if (m_currentReply && !m_currentReply->isFinished()) {
        qDebug() << "[WlanMonitor] Skipping check - previous request still in progress";
        return;
    }
    
    if (m_testUrls.isEmpty()) {
        qWarning() << "[WlanMonitor] No test URLs configured";
        return;
    }
    
    // Get current test URL and rotate for next time
    QString testUrl = m_testUrls[m_currentUrlIndex];
    rotateTestUrl();
    
    // Create request
    QUrl url(testUrl);
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "sdv-runtime/1.0");
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, 
                        QNetworkRequest::NoLessSafeRedirectPolicy);
    request.setTransferTimeout(m_timeout);
    
    // Send HEAD request (lightweight)
    m_currentReply = m_networkManager->head(request);
    
    // Connect signals only for this specific reply using single-shot connections
    connect(m_currentReply, &QNetworkReply::errorOccurred,
            this, &WlanMonitor::onNetworkError, Qt::UniqueConnection);
    connect(m_currentReply, &QNetworkReply::finished,
            this, &WlanMonitor::onNetworkReplyFinished, Qt::UniqueConnection);
    
    // qDebug() << "[WlanMonitor] Checking connectivity via:" << testUrl;
}

void WlanMonitor::onNetworkReplyFinished()
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) {
        qWarning() << "[WlanMonitor] onNetworkReplyFinished: No reply object found";
        return;
    }
    
    // Only process if this is our current reply
    if (reply != m_currentReply) {
        qDebug() << "[WlanMonitor] Ignoring finished signal from old reply";
        reply->deleteLater();
        return;
    }
    
    Status newStatus = Status::Disconnected;
    QString testUrl = reply->url().toString();
    
    // Success or 404 both indicate connectivity
    QNetworkReply::NetworkError error = reply->error();
    if (error == QNetworkReply::NoError || 
        error == QNetworkReply::ContentNotFoundError) {
        newStatus = Status::Connected;
        // qDebug() << "[WlanMonitor] Connection successful via:" << testUrl;
    } else {
        qDebug() << "[WlanMonitor] Connection failed via" << testUrl 
                 << "Error:" << error << reply->errorString();
    }
    
    // Handle status change
    handleStatusChange(newStatus);
    
    // Clean up current reply
    m_currentReply = nullptr;
    reply->deleteLater();
}

void WlanMonitor::onNetworkError(QNetworkReply::NetworkError error)
{
    QNetworkReply *reply = qobject_cast<QNetworkReply*>(sender());
    if (!reply) {
        return;
    }
    
    // Only process if this is our current reply
    if (reply != m_currentReply) {
        qDebug() << "[WlanMonitor] Ignoring error signal from old reply";
        return;
    }
    
    QString testUrl = reply->url().toString();
    qDebug() << "[WlanMonitor] Network error via" << testUrl 
             << "Error:" << error << reply->errorString();
    
    // The finished handler will deal with the status change and cleanup
}

void WlanMonitor::handleStatusChange(Status newStatus)
{
    if (newStatus == m_status) {
        return; // No change
    }
    
    Status oldStatus = m_status;
    m_status = newStatus;
    
    // Emit signals
    emit statusChanged(m_status);
    emit connectionStatusChanged(m_status == Status::Connected);
    
    if (newStatus == Status::Connected) {
        qDebug() << "[WlanMonitor] Internet connection restored";
        NOTIFY_SUCCESS("Internet", "Connection restored successfully");
        // Only emit connectionRestored if we were previously disconnected
        if (oldStatus == Status::Disconnected) {
            emit connectionRestored();
        }
    } else if (newStatus == Status::Disconnected) {
        qDebug() << "[WlanMonitor] Internet connection lost";
        NOTIFY_WARNING("Internet", "Connection lost - monitoring for restoration");
        // Only emit connectionLost if we were previously connected
        if (oldStatus == Status::Connected) {
            emit connectionLost();
        }
    }
}

void WlanMonitor::rotateTestUrl()
{
    m_currentUrlIndex = (m_currentUrlIndex + 1) % m_testUrls.size();
}