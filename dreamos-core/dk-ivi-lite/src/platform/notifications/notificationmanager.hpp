// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#ifndef NOTIFICATIONMANAGER_H
#define NOTIFICATIONMANAGER_H

#include <QObject>
#include <QTimer>
#include <QQueue>
#include <QJsonObject>
#include <QJsonArray>
#include <QDebug>
#include <QDateTime>
#include <QUuid>

// ───────────────────────────────────────────────────────────────
// Notification Types and Levels
// ───────────────────────────────────────────────────────────────
enum class NotificationLevel {
    Info,
    Success,
    Warning,
    Error,
    Progress
};

Q_DECLARE_METATYPE(NotificationLevel)

// ───────────────────────────────────────────────────────────────
// Notification Data Structure
// ───────────────────────────────────────────────────────────────
struct NotificationData {
    QString id;
    QString title;
    QString message;
    NotificationLevel level;
    int duration;           // Auto-dismiss duration in ms (0 = no auto-dismiss)
    int progress;           // Progress percentage (0-100, -1 = no progress)
    QString category;       // Category for grouping
    QString actionText;     // Optional action button text
    QString actionId;       // Action identifier
    QDateTime timestamp;
    bool persistent;        // Whether notification persists across app sessions
    bool autoQueue;         // Whether to queue if too many notifications
    
    NotificationData() : 
        level(NotificationLevel::Info), 
        duration(5000), 
        progress(-1),
        timestamp(QDateTime::currentDateTime()),
        persistent(false),
        autoQueue(true) {}
};

Q_DECLARE_METATYPE(NotificationData)

// ───────────────────────────────────────────────────────────────
// Modern Notification Manager - Singleton Pattern
// ───────────────────────────────────────────────────────────────
class NotificationManager : public QObject
{
    Q_OBJECT
    Q_PROPERTY(int maxVisibleNotifications READ maxVisibleNotifications WRITE setMaxVisibleNotifications NOTIFY maxVisibleNotificationsChanged)
    Q_PROPERTY(bool globalMute READ globalMute WRITE setGlobalMute NOTIFY globalMuteChanged)
    Q_PROPERTY(int totalNotifications READ totalNotifications NOTIFY totalNotificationsChanged)
    Q_PROPERTY(int unreadCount READ unreadCount NOTIFY unreadCountChanged)
    Q_PROPERTY(int queueCount READ queueCount NOTIFY queueCountChanged)

public:
    static NotificationManager& instance() {
        static NotificationManager instance;
        return instance;
    }

    // Core notification methods
    Q_INVOKABLE QString showNotification(const QString &title, 
                                        const QString &message,
                                        int level = 0,  // Info
                                        int duration = 5000,
                                        const QString &category = "general");

    Q_INVOKABLE QString showProgress(const QString &title,
                                    const QString &message,
                                    int progress = 0,
                                    const QString &category = "progress");

    Q_INVOKABLE void updateProgress(const QString &id, int progress, const QString &message = "");
    
    Q_INVOKABLE void dismissNotification(const QString &id);
    Q_INVOKABLE void dismissAll();
    Q_INVOKABLE void dismissCategory(const QString &category);
    
    // Internal synchronization method for QML auto-dismissals (no signal emission)
    Q_INVOKABLE void syncDismissedNotification(const QString &id);
    
    // Convenience methods for different levels
    Q_INVOKABLE QString info(const QString &title, const QString &message, const QString &category = "info");
    Q_INVOKABLE QString success(const QString &title, const QString &message, const QString &category = "success");
    Q_INVOKABLE QString warning(const QString &title, const QString &message, const QString &category = "warning");
    Q_INVOKABLE QString error(const QString &title, const QString &message, const QString &category = "error");
    
    // Task tracking methods
    Q_INVOKABLE QString startTask(const QString &taskName, const QString &description = "");
    Q_INVOKABLE void updateTask(const QString &taskId, int progress, const QString &status = "");
    Q_INVOKABLE void completeTask(const QString &taskId, const QString &result = "");
    Q_INVOKABLE void failTask(const QString &taskId, const QString &error = "");

    // Settings
    Q_INVOKABLE void setMaxVisibleNotifications(int max);
    Q_INVOKABLE int maxVisibleNotifications() const { return m_maxVisible; }
    
    Q_INVOKABLE void setGlobalMute(bool mute);
    Q_INVOKABLE bool globalMute() const { return m_globalMute; }
    
    Q_INVOKABLE int totalNotifications() const { return m_totalCount; }
    Q_INVOKABLE int unreadCount() const { return m_unreadCount; }
    Q_INVOKABLE int queueCount() const { return m_queue.size(); }

    // History and filtering
    Q_INVOKABLE QJsonArray getHistory(int limit = 50) const;
    Q_INVOKABLE QJsonArray getByCategory(const QString &category) const;
    Q_INVOKABLE void clearHistory();
    Q_INVOKABLE void markAllAsRead();

    // Smart notification methods with deduplication
    Q_INVOKABLE QString smartNotify(const QString &title, 
            const QString &message,
            int level = 0,
            const QString &category = "general",
            const QString &groupId = "");

    Q_INVOKABLE void updateOrCreate(const QString &groupId,
            const QString &title,
            const QString &message,
            int level = 0,
            const QString &category = "general");

    Q_INVOKABLE QString updateExisting(const QString &notificationId,
            const QString &newMessage,
            int newLevel = -1);
            
    Q_INVOKABLE void extendDuration(const QString &notificationId, int additionalMs = 3000);

    // Batch operations for multiple rapid notifications
    Q_INVOKABLE void startBatch(const QString &batchId);
    Q_INVOKABLE void addToBatch(const QString &batchId, const QString &title, const QString &message, int level = 0);
    Q_INVOKABLE void commitBatch(const QString &batchId, int maxNotifications = 3);

    // Category-based smart notifications
    Q_INVOKABLE QString categoryNotify(const QString &category,
            const QString &title,
            const QString &message,
            int level = 0,
            bool replaceExisting = true);

signals:
    // Core notification signals
    void notificationAdded(QString id, QString title, QString message, 
                          int level, int duration, QString category, 
                          int progress, QString actionText, QString actionId);
    void notificationUpdated(QString id, QString message, int progress);
    void notificationDismissed(QString id);
    void notificationAction(QString id, QString actionId);
    
    // Queue and management signals
    void queueChanged();
    void queueCountChanged();
    void maxVisibleNotificationsChanged();
    void globalMuteChanged();
    void totalNotificationsChanged();
    void unreadCountChanged();
    
    // Batch operations
    void allNotificationsDismissed();
    void categoryDismissed(QString category);

    // Add this new signal to your existing signals:
    void notificationExtended(QString id, int additionalMs);

public slots:
    void handleNotificationAction(const QString &id, const QString &actionId);
    void handleNotificationClick(const QString &id);

private slots:
    void processQueue();
    void handleAutoDissmiss();
    void cleanupOldNotifications();

private:
    explicit NotificationManager(QObject *parent = nullptr);
    ~NotificationManager() = default;
    
    // Disable copy constructor and assignment
    NotificationManager(const NotificationManager&) = delete;
    NotificationManager& operator=(const NotificationManager&) = delete;

    QString generateId() const;
    void addToHistory(const NotificationData &data);
    bool shouldQueue() const;
    void processNextInQueue();
    void startQueueProcessing();

    QQueue<NotificationData> m_queue;
    QList<NotificationData> m_activeNotifications;
    QList<NotificationData> m_history;
    QTimer *m_queueTimer;
    QTimer *m_cleanupTimer;
    
    int m_maxVisible = 10;
    int m_maxHistory = 200;
    bool m_globalMute = false;
    int m_totalCount = 0;
    int m_unreadCount = 0;
    
    // Task tracking
    QHash<QString, NotificationData> m_activeTasks;

    // Enhanced data structures
    QHash<QString, QString> m_groupToNotificationMap;  // groupId -> notificationId
    QHash<QString, QList<NotificationData>> m_batchedNotifications;  // batchId -> notifications
    QHash<QString, QDateTime> m_lastNotificationTime;  // category -> last time
    QHash<QString, QString> m_categoryToNotificationMap;  // category -> latest notificationId
    
    // Smart notification settings
    int m_minIntervalMs = 100;  // Minimum interval between same-category notifications
    int m_maxSimilarNotifications = 5;  // Max similar notifications before batching
    bool m_enableSmartBatching = true;
    // Queue processing settings
    static constexpr int QUEUE_PROCESS_INTERVAL = 50;  // 50ms instead of 300ms
    static constexpr int MAX_PROCESS_PER_CYCLE = 3;    // Process up to 3 at once
    
    // FIXED: Enhanced helper methods for better notification handling
    void processQueueImmediate();
    int countRecentNotifications(const QString &category, int timeWindowMs) const;

    // Add these new helper methods to your existing private methods:
    bool shouldBatch(const QString &category) const;
    bool isTooSoon(const QString &category) const;
    QString findSimilarNotification(const QString &title, const QString &category) const;
};

// ───────────────────────────────────────────────────────────────
// Convenience Macros for Easy Integration
// ───────────────────────────────────────────────────────────────
#define NOTIFY_INFO(title, message) \
    NotificationManager::instance().info(title, message)

#define NOTIFY_SUCCESS(title, message) \
    NotificationManager::instance().success(title, message)

#define NOTIFY_WARNING(title, message) \
    NotificationManager::instance().warning(title, message)

#define NOTIFY_ERROR(title, message) \
    NotificationManager::instance().error(title, message)

#define NOTIFY_PROGRESS(title, message, progress) \
    NotificationManager::instance().showProgress(title, message, progress)

#define START_TASK(name, desc) \
    NotificationManager::instance().startTask(name, desc)

#define UPDATE_TASK(id, progress, status) \
    NotificationManager::instance().updateTask(id, progress, status)

#define COMPLETE_TASK(id, result) \
    NotificationManager::instance().completeTask(id, result)

#define FAIL_TASK(id, error) \
    NotificationManager::instance().failTask(id, error)

// Smart notifications that update instead of creating duplicates
#define SMART_NOTIFY(category, title, msg, level) \
    NotificationManager::instance().categoryNotify(category, title, msg, level, true)

// Enhanced macros for consecutive notifications (guaranteed to show each one)
#define NOTIFY_INFO_ALWAYS(title, message) \
    NotificationManager::instance().showNotification(title, message, 0, 5000, QString("info_%1").arg(QDateTime::currentMSecsSinceEpoch() % 100000))

#define NOTIFY_SUCCESS_ALWAYS(title, message) \
    NotificationManager::instance().showNotification(title, message, 1, 4000, QString("success_%1").arg(QDateTime::currentMSecsSinceEpoch() % 100000))

#define NOTIFY_WARNING_ALWAYS(title, message) \
    NotificationManager::instance().showNotification(title, message, 2, 6000, QString("warning_%1").arg(QDateTime::currentMSecsSinceEpoch() % 100000))

// Process tracking
#define START_PROCESS(name, desc) \
    NotificationManager::instance().startTask(name, desc)

#define UPDATE_PROCESS(id, progress, status) \
    NotificationManager::instance().updateTask(id, progress, status)

#define COMPLETE_PROCESS(id, result) \
    NotificationManager::instance().completeTask(id, result)

#define FAIL_PROCESS(id, error) \
    NotificationManager::instance().failTask(id, error)

#endif // NOTIFICATIONMANAGER_H