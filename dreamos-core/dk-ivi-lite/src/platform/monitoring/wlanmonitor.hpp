#pragma once
#include <QObject>
#include <QTimer>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QNetworkRequest>
#include <QUrl>

/**
 * @brief Monitors WLAN/Internet connectivity status
 * 
 * This class encapsulates all WLAN monitoring functionality that was previously
 * embedded in InstalledAsyncBase template class.
 */
class WlanMonitor : public QObject
{
    Q_OBJECT
    Q_PROPERTY(bool connected READ isConnected NOTIFY connectionStatusChanged)
    
public:
    enum class Status { Unknown, Connected, Disconnected };
    Q_ENUM(Status)
    
    explicit WlanMonitor(QObject *parent = nullptr);
    ~WlanMonitor();
    
    // Status accessors
    bool isConnected() const { return m_status == Status::Connected; }
    Status status() const { return m_status; }
    
    // Configuration
    void setCheckInterval(int milliseconds);
    int checkInterval() const;
    
    void setTestUrls(const QStringList &urls);
    QStringList testUrls() const;
    
    void setTimeout(int milliseconds);
    int timeout() const;
    
public slots:
    void startMonitoring();
    void stopMonitoring();
    void checkConnectionNow();
    
signals:
    void connectionStatusChanged(bool connected);
    void statusChanged(WlanMonitor::Status status);
    void connectionRestored();
    void connectionLost();
    
private slots:
    void performConnectivityCheck();
    void onNetworkReplyFinished();
    void onNetworkError(QNetworkReply::NetworkError error);
    
private:
    void handleStatusChange(Status newStatus);
    void rotateTestUrl();
    
    QTimer *m_checkTimer;
    QNetworkAccessManager *m_networkManager;
    QNetworkReply *m_currentReply;
    
    Status m_status;
    QStringList m_testUrls;
    int m_currentUrlIndex;
    int m_checkInterval;
    int m_timeout;
    
    // Default configuration
    static constexpr int DEFAULT_CHECK_INTERVAL = 5000; // 5 seconds
    static constexpr int DEFAULT_TIMEOUT = 3000;        // 3 seconds
};

Q_DECLARE_METATYPE(WlanMonitor::Status)