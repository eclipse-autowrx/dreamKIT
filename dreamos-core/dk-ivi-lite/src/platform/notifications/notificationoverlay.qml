import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// ───────────────────────────────────────────────────────────────
// Modern Notification Overlay - Global UI Component - FIXED
// ───────────────────────────────────────────────────────────────
Item {
    id: notificationOverlay
    anchors.fill: parent
    z: 9999 // Ensure it's always on top
    
    property var notificationManagerInstance: null
    property int maxVisibleNotifications: 5
    property bool compactMode: false
    property string position: "topRight" // topRight, topLeft, bottomRight, bottomLeft, center
    property int margin: 24
    property int notificationWidth: 380
    property int notificationHeight: compactMode ? 64 : 96
    property int spacing: 12
    
    // Animation settings
    property int animationDuration: 400
    property int staggerDelay: 80
    
    // FIXED: Enhanced timer management with proper synchronization
    property var activeTimers: ({}) // Object to store timers by notification ID
    property var timerHandlers: ({}) // Store timer handler functions for proper cleanup
    property int timerDebugEnabled: 0 // Debug flag for timer lifecycle tracking
    property var notificationStatuses: ({}) // Track notification status to prevent duplicate operations
    
    // FIXED: Better initialization with retry mechanism
    Component.onCompleted: {
        // console.log("[NotificationOverlay] Component completed")
        // console.log("[NotificationOverlay] notificationManagerInstance:", notificationManagerInstance)
        // console.log("[NotificationOverlay] Parent:", parent)
        // console.log("[NotificationOverlay] Visible:", visible)
        // console.log("[NotificationOverlay] Z:", z)
        
        // Connect to the global notification manager
        if (notificationManagerInstance) {
            // console.log("[NotificationOverlay] Connecting to manager immediately...")
            connectToManager()
        } else {
            // console.log("[NotificationOverlay] No notificationManagerInstance, waiting...")
            
            // Try multiple times with increasing delays
            var attempts = 0
            var maxAttempts = 20 // Increased attempts
            
            function tryConnect() {
                attempts++
                // console.log("[NotificationOverlay] Connection attempt", attempts, "of", maxAttempts)
                
                if (notificationManagerInstance) {
                    // console.log("[NotificationOverlay] Found notificationManagerInstance on attempt", attempts)
                    connectToManager()
                    return
                }
                
                if (attempts < maxAttempts) {
                    Qt.callLater(tryConnect, attempts * 100)
                } else {
                    // console.log("[NotificationOverlay] ERROR: Failed to find notificationManagerInstance after", maxAttempts, "attempts")
                }
            }
            
            Qt.callLater(tryConnect, 100)
        }
    }

    // FIXED: Enhanced connection manager
    function connectToManager() {
        if (!notificationManagerInstance) {
            // console.log("[NotificationOverlay] ERROR: notificationManagerInstance is null in connectToManager")
            return
        }
        
        // console.log("[NotificationOverlay] Connecting to notification manager...")
        // console.log("[NotificationOverlay] Manager object:", notificationManagerInstance)
        
        try {
            // Connect to notification signals
            notificationManagerInstance.notificationAdded.connect(handleNotificationAdded)
            notificationManagerInstance.notificationDismissed.connect(handleNotificationDismissed)
            notificationManagerInstance.notificationUpdated.connect(handleNotificationUpdated)
            notificationManagerInstance.allNotificationsDismissed.connect(handleAllDismissed)
            notificationManagerInstance.notificationExtended.connect(handleNotificationExtended)
            
            // console.log("[NotificationOverlay] Successfully connected all signals")
            
            // Test connection by triggering a notification
            // Qt.callLater(function() {
            //     // console.log("[NotificationOverlay] Testing connection with startup notification...")
            //     notificationManagerInstance.success("System Ready", "Notification system connected successfully")
            // }, 500)
            
        } catch (error) {
            // console.log("[NotificationOverlay] ERROR connecting signals:", error)
        }
    }
    // FIXED: Enhanced auto-dismiss function with proper synchronization
    function setupAutoDismissEnhanced(id, duration) {
        if (duration <= 0) {
            if (timerDebugEnabled) console.log("[NotificationOverlay] Skipping timer setup for", id, "- duration:", duration)
            return
        }
        
        // FIXED: Check if notification is already being processed
        if (notificationStatuses[id] && notificationStatuses[id].dismissing) {
            if (timerDebugEnabled) console.log("[NotificationOverlay] Notification", id, "already being dismissed, skipping timer setup")
            return
        }
        
        if (timerDebugEnabled) console.log("[NotificationOverlay] Setting up timer for", id, "duration:", duration)
        
        // Mark notification as having an active timer
        notificationStatuses[id] = { hasTimer: true, dismissing: false }
        
        // Clean up any existing timer for this ID first
        cleanupTimerForId(id)
        
        // Add small random offset to prevent all timers firing simultaneously
        var randomOffset = Math.floor(Math.random() * 50) // Reduced to 0-49ms
        var adjustedDuration = duration + randomOffset
        
        try {
            // Create timer using a more robust approach
            var timerComponent = Qt.createComponent("Timer")
            if (timerComponent.status === Component.Ready) {
                var timer = timerComponent.createObject(notificationOverlay, {
                    "interval": adjustedDuration,
                    "repeat": false,
                    "running": false // Start manually after setup
                })
                
                if (timer) {
                    // Set up timer properties and connections
                    timer.notificationId = id
                    
                    // FIXED: Create dismissHandler with proper error handling and synchronization
                    var dismissHandler = function() {
                        if (timerDebugEnabled) console.log("[NotificationOverlay] Timer triggered for", id)
                        
                        // FIXED: Check if notification is already being dismissed
                        if (notificationStatuses[id] && notificationStatuses[id].dismissing) {
                            if (timerDebugEnabled) console.log("[NotificationOverlay] Notification", id, "already being dismissed by another process")
                            return
                        }
                        
                        // Mark as being dismissed to prevent race conditions
                        if (!notificationStatuses[id]) notificationStatuses[id] = {}
                        notificationStatuses[id].dismissing = true
                        
                        // Clean up timer reference immediately
                        cleanupTimerForId(id)
                        
                        // FIXED: Use local dismissal to avoid manager desync
                        handleNotificationDismissedInternal(id)
                    }
                    
                    // Store handler reference for proper cleanup
                    timerHandlers[id] = dismissHandler
                    timer.triggered.connect(dismissHandler)
                    
                    // Store timer reference before starting
                    activeTimers[id] = timer
                    
                    // Start the timer after everything is set up
                    timer.running = true
                    
                    if (timerDebugEnabled) console.log("[NotificationOverlay] Timer created and started for", id, "duration:", adjustedDuration)
                } else {
                    console.warn("[NotificationOverlay] Failed to create timer for", id)
                }
            } else {
                console.warn("[NotificationOverlay] Timer component not ready for", id)
                // Fallback to old method
                setupAutoDismissFallback(id, adjustedDuration)
            }
        } catch (error) {
            console.warn("[NotificationOverlay] Error creating timer for", id, ":", error)
            // Fallback to old method
            setupAutoDismissFallback(id, adjustedDuration)
        }
    }
    
    // FIXED: Fallback timer creation method with improved synchronization
    function setupAutoDismissFallback(id, duration) {
        if (timerDebugEnabled) console.log("[NotificationOverlay] Using fallback timer method for", id)
        
        var timer = Qt.createQmlObject(`
            import QtQuick
            Timer {
                property string notificationId: "${id}"
                running: true
                repeat: false
                interval: ${duration}
                onTriggered: {
                    var timerId = notificationId
                    if (notificationOverlay.timerDebugEnabled) {
                        // console.log("[NotificationOverlay] Fallback timer triggered for", timerId)
                    }
                    
                    // FIXED: Check for race conditions before dismissing
                    if (notificationOverlay.notificationStatuses[timerId] && notificationOverlay.notificationStatuses[timerId].dismissing) {
                        if (notificationOverlay.timerDebugEnabled) {
                            // console.log("[NotificationOverlay] Notification", timerId, "already being dismissed, skipping fallback timer")
                        }
                        return
                    }
                    
                    // Mark as being dismissed
                    if (!notificationOverlay.notificationStatuses[timerId]) {
                        notificationOverlay.notificationStatuses[timerId] = {}
                    }
                    notificationOverlay.notificationStatuses[timerId].dismissing = true
                    
                    notificationOverlay.cleanupTimerForId(timerId)
                    
                    // FIXED: Use internal dismissal to avoid manager conflicts
                    notificationOverlay.handleNotificationDismissedInternal(timerId)
                }
            }
        `, notificationOverlay)
        
        if (timer) {
            activeTimers[id] = timer
            if (timerDebugEnabled) console.log("[NotificationOverlay] Fallback timer created for", id)
        } else {
            console.error("[NotificationOverlay] Failed to create fallback timer for", id)
        }
    }
    
    // FIXED: Enhanced timer cleanup function with proper signal disconnection
    function cleanupTimerForId(id) {
        if (activeTimers[id]) {
            if (timerDebugEnabled) console.log("[NotificationOverlay] Cleaning up timer for", id)
            
            try {
                var timer = activeTimers[id]
                timer.running = false
                
                // FIXED: Improved signal disconnection using stored handler reference
                try {
                    if (timerHandlers[id] && timer.triggered) {
                        timer.triggered.disconnect(timerHandlers[id])
                        delete timerHandlers[id]
                        if (timerDebugEnabled) console.log("[NotificationOverlay] Successfully disconnected handler for", id)
                    }
                } catch (disconnectError) {
                    // This is expected for some timers, so reduce log noise
                    if (timerDebugEnabled) console.log("[NotificationOverlay] Handler already disconnected for", id)
                }
                
                // Remove from activeTimers immediately
                delete activeTimers[id]
                
                // Schedule destruction with delay to avoid races
                Qt.callLater(function() {
                    try {
                        if (timer && timer.destroy && typeof timer.destroy === 'function') {
                            timer.destroy()
                        }
                    } catch (destroyError) {
                        if (timerDebugEnabled) console.log("[NotificationOverlay] Timer destruction completed for", id)
                    }
                }, 50)
                
            } catch (error) {
                console.warn("[NotificationOverlay] Error cleaning up timer for", id, ":", error)
                // Force cleanup
                delete activeTimers[id]
                delete timerHandlers[id]
            }
        }
        
        // Clean up status tracking
        if (notificationStatuses[id]) {
            delete notificationStatuses[id]
        }
    }

    // FIXED: Enhanced notification handling with proper status tracking
    function handleNotificationAdded(id, title, message, level, duration, category, progress, actionText, actionId) {
        // console.log("[NotificationOverlay] *** handleNotificationAdded called ***")
        console.log("[NotificationOverlay] Title:", title)
        console.log("[NotificationOverlay] Message:", message)
        
        // FIXED: Initialize notification status tracking
        notificationStatuses[id] = { 
            hasTimer: duration > 0, 
            dismissing: false,
            addedToModel: false
        }
        
        var notification = {
            id: id,
            title: title,
            message: message,
            level: level,
            duration: duration,
            category: category,
            progress: progress,
            actionText: actionText || "",
            actionId: actionId || "",
            timestamp: new Date(),
            visible: false
        }
        
        try {
            notificationModel.append(notification)
            notificationStatuses[id].addedToModel = true
            // console.log("[NotificationOverlay] Model count after append:", notificationModel.count)
            
            // Animate in with stagger
            var index = notificationModel.count - 1
            // console.log("[NotificationOverlay] Animating notification at index:", index)
            
            Qt.callLater(function() {
                animateNotificationIn(index)
                
                // Set up auto-dismiss timer only for notifications with duration > 0
                if (duration > 0) {
                    setupAutoDismissEnhanced(id, duration)
                }
            }, 50)
            
            // Limit visible notifications
            while (notificationModel.count > maxVisibleNotifications) {
                if (timerDebugEnabled) console.log("[NotificationOverlay] Removing excess notification")
                var removedNotification = notificationModel.get(0)
                if (removedNotification) {
                    // Clean up timer for removed notification using improved method
                    cleanupTimerForId(removedNotification.id)
                }
                notificationModel.remove(0, 1)
            }
            
        } catch (error) {
            // console.log("[NotificationOverlay] ERROR in handleNotificationAdded:", error)
            // Clean up status on error
            delete notificationStatuses[id]
        }
    }
    
    // FIXED: Internal dismissal function that handles UI cleanup without circular calls
    function handleNotificationDismissedInternal(id) {
        if (timerDebugEnabled) console.log("[NotificationOverlay] Internal dismissal for ID:", id)
        
        // Clean up timer and status
        cleanupTimerForId(id)
        
        // Find and remove notification from model
        for (var i = 0; i < notificationModel.count; i++) {
            var notification = notificationModel.get(i)
            if (notification.id === id) {
                if (timerDebugEnabled) console.log("[NotificationOverlay] Found notification to dismiss at index:", i)
                animateNotificationOut(i)
                
                // CRITICAL FIX: After removing from UI, sync the manager's count without circular calls
                // This must be done AFTER UI removal to prevent circular calls
                Qt.callLater(function() {
                    if (notificationManagerInstance) {
                        try {
                            if (timerDebugEnabled) console.log("[NotificationOverlay] Syncing C++ manager for dismissed notification:", id)
                            // Use sync method to avoid signal emission and circular calls
                            notificationManagerInstance.syncDismissedNotification(id)
                        } catch (error) {
                            // console.log("[NotificationOverlay] Error syncing manager:", error)
                        }
                    }
                }, 0)
                return
            }
        }
        if (timerDebugEnabled) console.log("[NotificationOverlay] Notification", id, "not found in model (may have been already removed)")
    }
    
    // FIXED: External dismissal function for manager-triggered dismissals
    function handleNotificationDismissed(id) {
        if (timerDebugEnabled) console.log("[NotificationOverlay] External dismissal for ID:", id)
        
        // FIXED: Check if we're already processing this dismissal
        if (notificationStatuses[id] && notificationStatuses[id].dismissing) {
            if (timerDebugEnabled) console.log("[NotificationOverlay] Dismissal already in progress for", id)
            return
        }
        
        // Mark as being dismissed
        if (!notificationStatuses[id]) notificationStatuses[id] = {}
        notificationStatuses[id].dismissing = true
        
        // Use internal dismissal logic
        handleNotificationDismissedInternal(id)
    }
    
    function handleNotificationUpdated(id, message, progress) {
        // console.log("[NotificationOverlay] Updating notification:", id, "message:", message, "progress:", progress)
        for (var i = 0; i < notificationModel.count; i++) {
            var item = notificationModel.get(i)
            if (item.id === id) {
                notificationModel.setProperty(i, "message", message)
                notificationModel.setProperty(i, "progress", progress)
                // console.log("[NotificationOverlay] Updated notification at index:", i)
                break
            }
        }
    }
    
    function handleAllDismissed() {
        if (timerDebugEnabled) console.log("[NotificationOverlay] Handling dismiss all notifications")
        
        // Clean up all timers using the improved cleanup method
        var timerIds = Object.keys(activeTimers)
        for (var i = 0; i < timerIds.length; i++) {
            cleanupTimerForId(timerIds[i])
        }
        
        // FIXED: Clear all tracking objects
        activeTimers = {}
        timerHandlers = {}
        notificationStatuses = {}
        
        // Animate all out with stagger
        for (var i = 0; i < notificationModel.count; i++) {
            Qt.callLater(function(index) {
                return function() {
                    if (index < notificationModel.count) {
                        animateNotificationOut(index)
                    }
                }
            }(i), i * 100) // Stagger the animations
        }
    }
    
    // FIXED: Enhanced notification extension handling
    function handleNotificationExtended(id, additionalMs) {
        if (timerDebugEnabled) console.log("[NotificationOverlay] Extending notification:", id, "by", additionalMs, "ms")
        
        // Clean up existing timer using improved method
        cleanupTimerForId(id)
        
        // Create new extended timer
        setupAutoDismissEnhanced(id, additionalMs)
    }
    
    // FIXED: Auto-dismiss timer setup
    function setupAutoDismiss(index, id, duration) {
        if (duration <= 0) return
        
        // Add small random offset to prevent all timers firing simultaneously
        var randomOffset = Math.floor(Math.random() * 100) // 0-99ms random offset
        var adjustedDuration = duration + randomOffset
        
        // console.log("[NotificationOverlay] Setting up auto-dismiss for", id, "in", adjustedDuration, "ms (original:", duration, ")")
        
        var timer = Qt.createQmlObject('
            import QtQuick
            Timer {
                property string notificationId: ""
                property int modelIndex: -1
                running: true
                repeat: false
                onTriggered: {
                    // console.log("[NotificationOverlay] QML Timer auto-dismissing notification:", notificationId)
                    if (notificationManagerInstance) {
                        notificationManagerInstance.dismissNotification(notificationId)
                    } else {
                        // Fallback to local dismissal
                        handleNotificationDismissed(notificationId)
                    }
                    destroy()
                }
            }
        ', notificationOverlay)
        
        timer.interval = adjustedDuration
        timer.notificationId = id
        timer.modelIndex = index
        
        // Store reference to timer in model
        if (index < notificationModel.count) {
            notificationModel.setProperty(index, "dismissTimer", timer)
        }
    }

    function animateNotificationInActual(item, index) {
        // console.log("[NotificationOverlay] Animating in notification at index:", index)
        // console.log("[NotificationOverlay] Item properties - x:", item.x, "y:", item.y, "width:", item.width, "height:", item.height)
        
        // Set initial state
        item.opacity = 0
        item.scale = 0.8
        
        // Calculate positions
        var targetX = getNotificationX()
        var targetY = getNotificationY(index)
        
        // console.log("[NotificationOverlay] Target position - x:", targetX, "y:", targetY)
        
        // Set initial position (slightly offset)
        item.x = targetX + 50
        item.y = targetY
        
        // Make visible immediately
        item.visible = true
        notificationModel.setProperty(index, "visible", true)
        
        // console.log("[NotificationOverlay] Starting entrance animation for index:", index)
        
        // Animate in with delay
        Qt.callLater(function() {
            // Create individual animations for this item
            var opacityAnim = Qt.createQmlObject(`
                import QtQuick
                NumberAnimation {
                    target: null
                    property: "opacity"
                    from: 0
                    to: 1
                    duration: ${animationDuration}
                    easing.type: Easing.OutCubic
                }
            `, notificationOverlay)
            
            var scaleAnim = Qt.createQmlObject(`
                import QtQuick
                NumberAnimation {
                    target: null
                    property: "scale"
                    from: 0.8
                    to: 1.0
                    duration: ${animationDuration}
                    easing.type: Easing.OutBack
                    easing.overshoot: 1.2
                }
            `, notificationOverlay)
            
            var xAnim = Qt.createQmlObject(`
                import QtQuick
                NumberAnimation {
                    target: null
                    property: "x"
                    to: ${targetX}
                    duration: ${animationDuration}
                    easing.type: Easing.OutCubic
                }
            `, notificationOverlay)
            
            // Set targets and start
            opacityAnim.target = item
            scaleAnim.target = item
            xAnim.target = item
            
            opacityAnim.start()
            scaleAnim.start()
            xAnim.start()
            
            // Clean up animations when done
            opacityAnim.finished.connect(function() { opacityAnim.destroy() })
            scaleAnim.finished.connect(function() { scaleAnim.destroy() })
            xAnim.finished.connect(function() { xAnim.destroy() })
            
        }, index * staggerDelay)
    }
    
    function animateNotificationIn(index) {
        var item = notificationRepeater.itemAt(index)
        if (!item) {
            // console.log("[NotificationOverlay] ERROR: No item found at index", index, "- repeater count:", notificationRepeater.count)
            // console.log("[NotificationOverlay] Model count:", notificationModel.count)
            
            // Try to wait a bit and retry
            Qt.callLater(function() {
                var retryItem = notificationRepeater.itemAt(index)
                if (retryItem) {
                    // console.log("[NotificationOverlay] Retry successful for index:", index)
                    animateNotificationInActual(retryItem, index)
                } else {
                    // console.log("[NotificationOverlay] Retry failed for index:", index)
                }
            }, 100)
            return
        }
        
        animateNotificationInActual(item, index)
    }
    
    function animateNotificationOut(index) {
        // console.log("[NotificationOverlay] Animating out notification at index:", index)
        
        if (index < 0 || index >= notificationModel.count) {
            // console.log("[NotificationOverlay] Invalid index for animation out:", index)
            return
        }
        
        var item = notificationRepeater.itemAt(index)
        if (!item) {
            // console.log("[NotificationOverlay] No item found, removing directly from model")
            notificationModel.remove(index, 1)
            return
        }
        
        // Exit animation
        exitAnimation.target = item
        exitAnimation.targetIndex = index
        exitAnimation.start()
    }
    
    function getNotificationX() {
        switch (position) {
            case "topLeft":
            case "bottomLeft":
                return margin
            case "topRight":
            case "bottomRight":
                return parent.width - notificationWidth - margin
            case "center":
                return (parent.width - notificationWidth) / 2
            default:
                return parent.width - notificationWidth - margin
        }
    }
    
    function getNotificationY(index) {
        var baseY
        // console.log("[NotificationOverlay] Calculating Y position for index:", index, "position:", position)
        
        switch (position) {
            case "topLeft":
            case "topRight":
                baseY = margin
                var calculatedY = baseY + index * (notificationHeight + spacing)
                // console.log("[NotificationOverlay] Top position - baseY:", baseY, "calculatedY:", calculatedY, "index:", index)
                return calculatedY
                
            case "bottomLeft":
            case "bottomRight":
                baseY = parent.height - margin - notificationHeight
                var calculatedY = baseY - index * (notificationHeight + spacing)
                // console.log("[NotificationOverlay] Bottom position - baseY:", baseY, "calculatedY:", calculatedY, "index:", index)
                return calculatedY
                
            case "center":
                var totalHeight = maxVisibleNotifications * (notificationHeight + spacing) - spacing
                baseY = (parent.height - totalHeight) / 2
                var calculatedY = baseY + index * (notificationHeight + spacing)
                // console.log("[NotificationOverlay] Center position - baseY:", baseY, "calculatedY:", calculatedY, "index:", index)
                return calculatedY
                
            default:
                baseY = margin
                var calculatedY = baseY + index * (notificationHeight + spacing)
                // console.log("[NotificationOverlay] Default position - baseY:", baseY, "calculatedY:", calculatedY, "index:", index)
                return calculatedY
        }
    }
    
    function getLevelColor(level) {
        switch (level) {
            case 0: return "#4A90E2" // Info - Blue
            case 1: return "#00D4AA" // Success - Green
            case 2: return "#F5A623" // Warning - Orange
            case 3: return "#D0021B" // Error - Red
            case 4: return "#7ED321" // Progress - Light Green
            default: return "#4A90E2"
        }
    }
    
    function getLevelIcon(level) {
        switch (level) {
            case 0: return "ℹ" // Info
            case 1: return "✓" // Success
            case 2: return "⚠" // Warning
            case 3: return "✕" // Error
            case 4: return "⟳" // Progress
            default: return "ℹ"
        }
    }
    
    // Notification model
    ListModel {
        id: notificationModel
    }
    
    // FIXED: Enhanced animation definitions with proper cleanup
    ParallelAnimation {
        id: enterAnimation
        property var target: null
        
        NumberAnimation {
            target: enterAnimation.target
            property: "opacity"
            from: 0
            to: 1
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
        
        NumberAnimation {
            target: enterAnimation.target
            property: "scale"
            from: 0.8
            to: 1.0
            duration: animationDuration
            easing.type: Easing.OutBack
            easing.overshoot: 1.2
        }
        
        NumberAnimation {
            target: enterAnimation.target
            property: "x"
            to: getNotificationX()
            duration: animationDuration
            easing.type: Easing.OutCubic
        }
    }
    
    // FIXED: Enhanced exit animation with proper cleanup
    ParallelAnimation {
        id: exitAnimation
        property var target: null
        property int targetIndex: -1
        
        NumberAnimation {
            target: exitAnimation.target
            property: "opacity"
            to: 0
            duration: animationDuration * 0.7
            easing.type: Easing.InCubic
        }
        
        NumberAnimation {
            target: exitAnimation.target
            property: "scale"
            to: 0.8
            duration: animationDuration * 0.7
            easing.type: Easing.InBack
        }
        
        NumberAnimation {
            target: exitAnimation.target
            property: "x"
            to: getNotificationX() + 100
            duration: animationDuration * 0.7
            easing.type: Easing.InCubic
        }
        
        onFinished: {
            // console.log("[NotificationOverlay] Exit animation finished for index:", targetIndex)
            if (targetIndex >= 0 && targetIndex < notificationModel.count) {
                notificationModel.remove(targetIndex, 1)
            }
            target = null
            targetIndex = -1
        }
    }
    
    // Notification items
    Repeater {
        id: notificationRepeater
        model: notificationModel
        
        delegate: Item {
            id: notificationItem
            width: notificationWidth
            height: notificationHeight
            
            // FIXED: Explicit positioning instead of relying on functions
            property int notificationIndex: index
            property real targetX: {
                switch (position) {
                    case "topLeft":
                    case "bottomLeft":
                        return margin
                    case "topRight":
                    case "bottomRight":
                        return parent.width - notificationWidth - margin
                    case "center":
                        return (parent.width - notificationWidth) / 2
                    default:
                        return parent.width - notificationWidth - margin
                }
            }
            
            property real targetY: {
                var baseY
                switch (position) {
                    case "topLeft":
                    case "topRight":
                        baseY = margin
                        return baseY + notificationIndex * (notificationHeight + spacing)
                    case "bottomLeft":
                    case "bottomRight":
                        baseY = parent.height - margin - notificationHeight
                        return baseY - notificationIndex * (notificationHeight + spacing)
                    case "center":
                        var totalHeight = maxVisibleNotifications * (notificationHeight + spacing) - spacing
                        baseY = (parent.height - totalHeight) / 2
                        return baseY + notificationIndex * (notificationHeight + spacing)
                    default:
                        baseY = margin
                        return baseY + notificationIndex * (notificationHeight + spacing)
                }
            }
            
            // Set initial position
            x: targetX
            y: targetY
            visible: false
            
            // Debug output
            Component.onCompleted: {
                // console.log("[NotificationOverlay] Delegate created for index:", notificationIndex, 
                //         "x:", x, "y:", y, "targetX:", targetX, "targetY:", targetY)
            }
            
            // Smooth position transitions when other notifications are removed
            Behavior on y {
                NumberAnimation {
                    duration: 300
                    easing.type: Easing.OutCubic
                }
            }
            
            // Main notification card
            Rectangle {
                id: notificationCard
                anchors.fill: parent
                radius: 16
                color: "#1A1A1A"
                border.color: getLevelColor(model.level)
                border.width: 2
                
                // Enhanced glassmorphism effect
                Rectangle {
                    id: glassEffect
                    anchors.fill: parent
                    anchors.margins: 2
                    radius: parent.radius - 2
                    color: "#FFFFFF"
                    opacity: 0.05
                }
                
                // Animated accent bar
                Rectangle {
                    id: accentBar
                    width: 4
                    height: parent.height - 16
                    x: 8
                    y: 8
                    radius: 2
                    color: getLevelColor(model.level)
                    
                    // Breathing animation
                    SequentialAnimation on opacity {
                        loops: Animation.Infinite
                        NumberAnimation { to: 0.6; duration: 2000 }
                        NumberAnimation { to: 1.0; duration: 2000 }
                    }
                }
                
                // Progress bar (for progress notifications)
                Rectangle {
                    id: progressBackground
                    anchors.bottom: parent.bottom
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.margins: 2
                    height: 4
                    radius: 2
                    color: "#2A2A2A"
                    visible: model.progress >= 0
                    
                    Rectangle {
                        id: progressBar
                        anchors.left: parent.left
                        anchors.top: parent.top
                        anchors.bottom: parent.bottom
                        width: parent.width * Math.max(0, Math.min(100, model.progress)) / 100
                        radius: parent.radius
                        color: getLevelColor(model.level)
                        
                        // Smooth progress transitions
                        Behavior on width {
                            NumberAnimation {
                                duration: 300
                                easing.type: Easing.OutCubic
                            }
                        }
                        
                        // Shimmer effect for progress
                        Rectangle {
                            width: 20
                            height: parent.height
                            color: "#FFFFFF"
                            opacity: 0.3
                            radius: parent.radius
                            
                            SequentialAnimation on x {
                                loops: model.progress < 100 ? Animation.Infinite : 0
                                NumberAnimation {
                                    from: -20
                                    to: progressBar.width + 20
                                    duration: 1500
                                    easing.type: Easing.InOutCubic
                                }
                                PauseAnimation { duration: 500 }
                            }
                        }
                    }
                }
                
                // Content layout
                RowLayout {
                    anchors.fill: parent
                    anchors.margins: 16
                    anchors.bottomMargin: model.progress >= 0 ? 24 : 16
                    spacing: 12
                    
                    // Icon container
                    Rectangle {
                        width: compactMode ? 32 : 40
                        height: width
                        radius: width / 2
                        color: getLevelColor(model.level)
                        opacity: 0.2
                        border.color: getLevelColor(model.level)
                        border.width: 1
                        Layout.alignment: Qt.AlignTop
                        
                        Text {
                            anchors.centerIn: parent
                            text: getLevelIcon(model.level)
                            font.pixelSize: compactMode ? 14 : 18
                            color: getLevelColor(model.level)
                            font.family: "Segoe UI"
                            font.weight: Font.Bold
                        }
                        
                        // Rotating animation for progress notifications
                        RotationAnimation on rotation {
                            running: model.level === 4 && model.progress < 100
                            loops: Animation.Infinite
                            from: 0
                            to: 360
                            duration: 2000
                        }
                    }
                    
                    // Text content
                    ColumnLayout {
                        Layout.fillWidth: true
                        Layout.alignment: Qt.AlignVCenter
                        spacing: compactMode ? 2 : 4
                        
                        Text {
                            text: model.title || "Notification"
                            font.pixelSize: compactMode ? 14 : 16
                            font.weight: Font.DemiBold
                            color: "#FFFFFF"
                            font.family: "Segoe UI"
                            Layout.fillWidth: true
                            elide: Text.ElideRight
                            maximumLineCount: 1
                        }
                        
                        Text {
                            text: model.message || ""
                            font.pixelSize: compactMode ? 12 : 14
                            color: "#B0B0B0"
                            font.family: "Segoe UI"
                            Layout.fillWidth: true
                            wrapMode: compactMode ? Text.NoWrap : Text.WordWrap
                            elide: compactMode ? Text.ElideRight : Text.ElideNone
                            maximumLineCount: compactMode ? 1 : 4
                            lineHeight: 1.2
                        }
                        
                        // Progress text for progress notifications
                        Text {
                            text: model.progress >= 0 ? model.progress + "%" : ""
                            font.pixelSize: 11
                            color: getLevelColor(model.level)
                            font.family: "Segoe UI"
                            font.weight: Font.Medium
                            visible: model.progress >= 0
                        }
                    }
                    
                    // Action button (if available)
                    Button {
                        visible: model.actionText && model.actionText.length > 0
                        text: model.actionText || ""
                        Layout.preferredWidth: 80
                        Layout.preferredHeight: 28
                        
                        background: Rectangle {
                            radius: 14
                            color: parent.hovered ? getLevelColor(model.level) : "transparent"
                            border.color: getLevelColor(model.level)
                            border.width: 1
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                        
                        contentItem: Text {
                            text: parent.text
                            color: parent.hovered ? "#FFFFFF" : getLevelColor(model.level)
                            font.family: "Segoe UI"
                            font.pixelSize: 11
                            font.weight: Font.Medium
                            horizontalAlignment: Text.AlignHCenter
                            verticalAlignment: Text.AlignVCenter
                            
                            Behavior on color {
                                ColorAnimation { duration: 200 }
                            }
                        }
                        
                        onClicked: {
                            if (notificationManagerInstance && model.actionId) {
                                notificationManagerInstance.handleNotificationAction(model.id, model.actionId)
                            }
                        }
                    }
                    
                    // ENHANCED: Close button with improved debugging and event handling
                    Rectangle {
                        id: closeButton
                        width: 24
                        height: 24
                        radius: 12
                        color: closeArea.containsMouse ? (closeArea.pressed ? "#FF6666" : "#FF4444") : "#2A2A2A"
                        border.color: closeArea.containsMouse ? "#FF4444" : "#404040"
                        border.width: 1
                        Layout.alignment: Qt.AlignTop
                        z: 1000 // Much higher z-index to ensure it's always on top
                        
                        Behavior on color { ColorAnimation { duration: 200 } }
                        Behavior on border.color { ColorAnimation { duration: 200 } }
                        Behavior on scale { NumberAnimation { duration: 100 } }
                        
                        // Enhanced background highlight to make button more visible
                        // Rectangle {
                        //     anchors.centerIn: parent
                        //     width: parent.width + 6
                        //     height: parent.height + 6
                        //     radius: (parent.width + 6) / 2
                        //     color: closeArea.containsMouse ? "#FF4444" : "#000000"
                        //     opacity: closeArea.containsMouse ? 0.2 : 0.15
                        //     z: -1
                            
                        //     // Pulsing animation when hovered
                        //     SequentialAnimation on opacity {
                        //         running: closeArea.containsMouse
                        //         loops: Animation.Infinite
                        //         NumberAnimation { to: 0.3; duration: 600 }
                        //         NumberAnimation { to: 0.1; duration: 600 }
                        //     }
                        // }
                        
                        Text {
                            id: closeText
                            anchors.centerIn: parent
                            text: "✕" // Using a more visible close symbol
                            color: closeArea.containsMouse ? "#FFFFFF" : "#E0E0E0"
                            font.pixelSize: 14
                            font.weight: Font.Bold
                            font.family: "Segoe UI"
                            scale: closeArea.containsMouse ? (closeArea.pressed ? 0.8 : 1.1) : 1.0
                            
                            Behavior on color { ColorAnimation { duration: 200 } }
                            Behavior on scale { NumberAnimation { duration: 150; easing.type: Easing.OutBack } }
                        }
                        
                        MouseArea {
                            id: closeArea
                            anchors.fill: parent
                            anchors.margins: -4 // Reasonable clickable area expansion
                            hoverEnabled: true
                            cursorShape: Qt.PointingHandCursor
                            z: 2000 // Highest z-index to ensure priority
                            acceptedButtons: Qt.LeftButton
                            propagateComposedEvents: false // Don't propagate to parent MouseAreas
                            enabled: true // Explicitly enable to ensure it captures events
                            preventStealing: true // Prevent parent MouseAreas from stealing events
                            
                            // Enhanced debug visualization - enabled by default for testing
                            Rectangle {
                                anchors.fill: parent
                                color: "red"
                                opacity: 0.2
                                border.color: "yellow"
                                border.width: 1
                                visible: notificationOverlay.timerDebugEnabled === 1
                            }
                            
                            onClicked: {
                                // console.log("[NotificationOverlay] === CLOSE BUTTON CLICKED ===")
                                // console.log("[NotificationOverlay] Notification ID:", model.id)
                                // console.log("[NotificationOverlay] Mouse position:", mouse.x, mouse.y)
                                
                                mouse.accepted = true // Explicitly accept the event
                                
                                // FIXED: Check if already being dismissed to prevent duplicate actions
                                if (notificationOverlay.notificationStatuses[model.id] && notificationOverlay.notificationStatuses[model.id].dismissing) {
                                    // console.log("[NotificationOverlay] Notification", model.id, "already being dismissed")
                                    return
                                }
                                
                                // Mark as being dismissed to prevent race conditions
                                if (!notificationOverlay.notificationStatuses[model.id]) {
                                    notificationOverlay.notificationStatuses[model.id] = {}
                                }
                                notificationOverlay.notificationStatuses[model.id].dismissing = true
                                
                                // Clean up timer
                                notificationOverlay.cleanupTimerForId(model.id)
                                
                                // FIXED: Use internal dismissal for immediate UI response, then notify manager
                                // console.log("[NotificationOverlay] Using direct dismissal for immediate response")
                                notificationOverlay.handleNotificationDismissedInternal(model.id)
                                
                                // Notify manager asynchronously to keep it in sync
                                Qt.callLater(function() {
                                    if (notificationManagerInstance) {
                                        try {
                                            notificationManagerInstance.dismissNotification(model.id)
                                        } catch (error) {
                                            // Manager may have already dismissed it, that's fine
                                            // console.log("[NotificationOverlay] Manager dismissal completed or already done for", model.id)
                                        }
                                    }
                                }, 0)
                            }
                            
                            onPressed: {
                                // console.log("[NotificationOverlay] Close button pressed")
                                closeButton.scale = 0.9
                                mouse.accepted = true
                            }
                            
                            onReleased: {
                                // console.log("[NotificationOverlay] Close button released")
                                closeButton.scale = 1.0
                            }
                            
                            onCanceled: {
                                // console.log("[NotificationOverlay] Close button canceled")
                                closeButton.scale = 1.0
                            }
                            
                            onEntered: {
                                // console.log("[NotificationOverlay] Close button mouse entered")
                            }
                            
                            onExited: {
                                // console.log("[NotificationOverlay] Close button mouse exited")
                            }
                        }
                    }
                }
                
                // Click handler for entire notification
                MouseArea {
                    id: notificationClickArea
                    anchors.fill: parent
                    acceptedButtons: Qt.LeftButton
                    z: 1 // Much lower z-index than close button
                    propagateComposedEvents: false // Don't propagate to avoid conflicts
                    
                    onClicked: function(mouse) {
                        // console.log("[NotificationOverlay] Notification body clicked at:", mouse.x, mouse.y)
                        
                        // Calculate close button area (32x32 button with LayoutAlignment and margins)
                        var closeButtonArea = {
                            x: parent.width - 44, // Account for button width + margins
                            y: 0,
                            width: 44,
                            height: 44
                        }
                        
                        var clickInCloseArea = (mouse.x >= closeButtonArea.x && mouse.x <= (closeButtonArea.x + closeButtonArea.width) &&
                                              mouse.y >= closeButtonArea.y && mouse.y <= (closeButtonArea.y + closeButtonArea.height))
                        
                        // console.log("[NotificationOverlay] Click at:", mouse.x, mouse.y, "Close area:", closeButtonArea.x, closeButtonArea.y, closeButtonArea.width, closeButtonArea.height, "In close area:", clickInCloseArea)
                        
                        if (clickInCloseArea) {
                            // FIXED: Handle close button click with proper synchronization
                            // console.log("[NotificationOverlay] Close button clicked via notification area - handling dismissal")
                            
                            // Check if already being dismissed
                            if (notificationOverlay.notificationStatuses[model.id] && notificationOverlay.notificationStatuses[model.id].dismissing) {
                                // console.log("[NotificationOverlay] Notification", model.id, "already being dismissed")
                                return
                            }
                            
                            // Mark as being dismissed
                            if (!notificationOverlay.notificationStatuses[model.id]) {
                                notificationOverlay.notificationStatuses[model.id] = {}
                            }
                            notificationOverlay.notificationStatuses[model.id].dismissing = true
                            
                            // Clean up timer
                            notificationOverlay.cleanupTimerForId(model.id)
                            
                            // Use direct dismissal for immediate response
                            // console.log("[NotificationOverlay] Using direct dismissal for immediate response")
                            notificationOverlay.handleNotificationDismissedInternal(model.id)
                            
                            // Notify manager asynchronously
                            Qt.callLater(function() {
                                if (notificationManagerInstance) {
                                    try {
                                        notificationManagerInstance.dismissNotification(model.id)
                                    } catch (error) {
                                        // console.log("[NotificationOverlay] Manager dismissal completed for", model.id)
                                    }
                                }
                            }, 0)
                        } else {
                            // console.log("[NotificationOverlay] Handling notification body click for ID:", model.id)
                            if (notificationManagerInstance) {
                                notificationManagerInstance.handleNotificationClick(model.id)
                            }
                        }
                    }
                }
                
                // Hover effects
                MouseArea {
                    id: hoverArea
                    anchors.fill: parent
                    hoverEnabled: true
                    acceptedButtons: Qt.NoButton
                    z: 0 // Lowest z-index
                    propagateComposedEvents: false // Don't propagate - this is just for hover
                    
                    onEntered: {
                        // console.log("[NotificationOverlay] Notification hover entered")
                        notificationCard.scale = 1.02
                        glassEffect.opacity = 0.08
                    }
                    
                    onExited: {
                        // console.log("[NotificationOverlay] Notification hover exited")
                        notificationCard.scale = 1.0
                        glassEffect.opacity = 0.05
                    }
                }
                
                Behavior on scale {
                    NumberAnimation {
                        duration: 200
                        easing.type: Easing.OutCubic
                    }
                }
            }
            
            // Drop shadow effect
            Rectangle {
                anchors.fill: notificationCard
                anchors.margins: -2
                radius: notificationCard.radius + 2
                color: "#000000"
                opacity: 0.2
                z: -1
                
                // Shadow blur simulation with multiple layers
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -1
                    radius: parent.radius + 1
                    color: "#000000"
                    opacity: 0.1
                    z: -1
                }
                
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -2
                    radius: parent.radius + 2
                    color: "#000000"
                    opacity: 0.05
                    z: -1
                }
            }
        }
    }
    
    // FIXED: Queue indicator with actual queue count
    Rectangle {
        id: queueIndicator
        visible: notificationManagerInstance ? notificationManagerInstance.queueCount > 0 : false
        anchors.right: position.includes("Right") ? parent.right : undefined
        anchors.left: position.includes("Left") ? parent.left : undefined
        anchors.bottom: position.includes("bottom") ? parent.bottom : undefined
        anchors.top: position.includes("top") ? parent.top : undefined
        anchors.margins: margin
        
        width: 120
        height: 32
        radius: 16
        color: "#2A2A2A"
        border.color: "#00D4AA"
        border.width: 1
        opacity: 0.9
        
        Text {
            anchors.centerIn: parent
            text: notificationManagerInstance ? (notificationManagerInstance.queueCount + " queued") : "Queued"
            color: "#00D4AA"
            font.family: "Segoe UI"
            font.pixelSize: 12
            font.weight: Font.Medium
        }
        
        MouseArea {
            anchors.fill: parent
            onClicked: {
                // Handle queue expansion or show notification center
                // console.log("[NotificationOverlay] Queue indicator clicked - showing queued notifications")
                if (notificationManagerInstance) {
                    // Could implement a function to show all queued notifications
                }
            }
        }
        
        // Pulsing animation for queue indicator
        SequentialAnimation on opacity {
            running: queueIndicator.visible
            loops: Animation.Infinite
            NumberAnimation { to: 0.6; duration: 1000 }
            NumberAnimation { to: 0.9; duration: 1000 }
        }
    }
    
    // FIXED: Enhanced notification test functions
    function testNotifications() {
        if (!notificationManagerInstance) {
            // console.log("[NotificationOverlay] Cannot test - no notification manager instance")
            return
        }
        
        // console.log("[NotificationOverlay] Starting notification tests...")
        
        // Test consecutive notifications to verify queue works
        notificationManagerInstance.info("Test 1", "First info notification")
        notificationManagerInstance.info("Test 2", "Second info notification")
        notificationManagerInstance.info("Test 3", "Third info notification")
        notificationManagerInstance.info("Test 4", "Fourth info notification")
        notificationManagerInstance.info("Test 5", "Fifth info notification")
        notificationManagerInstance.info("Test 6", "Sixth info notification - should be queued")
        notificationManagerInstance.info("Test 7", "Seventh info notification - should be queued")
        
        Qt.callLater(function() {
            notificationManagerInstance.success("Success!", "Operation completed successfully")
        }, 1000)
        
        Qt.callLater(function() {
            notificationManagerInstance.warning("Warning", "Please check your settings")
        }, 2000)
        
        Qt.callLater(function() {
            // Test error notification that should be dismissible
            notificationManagerInstance.error("Error Test", "This error should be manually dismissible")
        }, 3000)
        
        Qt.callLater(function() {
            var taskId = notificationManagerInstance.startTask("Installing App", "Downloading packages...")
            
            // Simulate progress updates
            var progress = 0
            var timer = Qt.createQmlObject('import QtQuick; Timer {}', notificationOverlay)
            timer.interval = 200
            timer.repeat = true
            timer.triggered.connect(function() {
                progress += Math.random() * 15
                if (progress >= 100) {
                    progress = 100
                    timer.stop()
                    notificationManagerInstance.completeTask(taskId, "App installed successfully!")
                    timer.destroy()
                } else {
                    notificationManagerInstance.updateTask(taskId, Math.floor(progress), "Installing... " + Math.floor(progress) + "%")
                }
            })
            timer.start()
        }, 4000)
    }
    
    function testErrorNotification() {
        if (!notificationManagerInstance) return
        notificationManagerInstance.error("Critical Error", "This is a test error notification that should be dismissible")
    }
    
    function testQueue() {
        if (!notificationManagerInstance) return
        
        // console.log("[NotificationOverlay] Testing queue with rapid notifications...")
        for (var i = 1; i <= 10; i++) {
            notificationManagerInstance.info("Queue Test " + i, "Testing notification queue system - item " + i)
        }
    }
    
    // FIXED: Enhanced test function to validate auto-dismiss timer fixes
    function testAutoDismissFix() {
        if (!notificationManagerInstance) return
        
        // console.log("[NotificationOverlay] Testing auto-dismiss timer fixes...")
        timerDebugEnabled = 1
        
        // Test rapid notifications that should all auto-dismiss
        notificationManagerInstance.info("Auto-Dismiss Test 1", "This should auto-dismiss in ~5 seconds")
        Qt.callLater(function() {
            notificationManagerInstance.success("Auto-Dismiss Test 2", "This should auto-dismiss in ~4 seconds")
        }, 200)
        Qt.callLater(function() {
            notificationManagerInstance.warning("Auto-Dismiss Test 3", "This should auto-dismiss in ~6 seconds")
        }, 400)
        Qt.callLater(function() {
            notificationManagerInstance.error("Manual Dismiss Test", "This ERROR should stay until manually dismissed (duration=0)")
        }, 600)
        
        // Show timer status after creation
        Qt.callLater(function() {
            var timerCount = Object.keys(activeTimers).length
            // console.log("[NotificationOverlay] Created", timerCount, "active timers for auto-dismiss test")
            // console.log("[NotificationOverlay] Timer IDs:", Object.keys(activeTimers))
        }, 1000)
        
        // Check timer cleanup after some dismissals
        Qt.callLater(function() {
            var timerCount = Object.keys(activeTimers).length
            var pendingCount = pendingTimerCleanup.length
            // console.log("[NotificationOverlay] After 8 seconds - Active timers:", timerCount, "Pending cleanup:", pendingCount)
            if (timerCount === 1) {
                // console.log("[NotificationOverlay] SUCCESS: Only error notification should remain (has no auto-dismiss timer)")
            } else {
                // console.log("[NotificationOverlay] WARNING: Unexpected timer count. Expected 1, got", timerCount)
            }
        }, 8000)
    }
    
    // FIXED: Enhanced shortcuts for testing and debugging
    Shortcut {
        sequence: "Ctrl+Shift+N"
        onActivated: testNotifications()
    }
    
    Shortcut {
        sequence: "Ctrl+Shift+E"
        onActivated: testErrorNotification()
    }
    
    Shortcut {
        sequence: "Ctrl+Shift+Q"
        onActivated: testQueue()
    }
    
    Shortcut {
        sequence: "Ctrl+Shift+C"
        onActivated: {
            if (notificationManagerInstance) {
                notificationManagerInstance.dismissAll()
            }
        }
    }
    
    // Debug shortcut to toggle timer debugging
    Shortcut {
        sequence: "Ctrl+Shift+D"
        onActivated: {
            timerDebugEnabled = timerDebugEnabled ? 0 : 1
            // console.log("[NotificationOverlay] Timer debugging", timerDebugEnabled ? "enabled" : "disabled")
        }
    }
    
    // Debug shortcut to show timer status
    Shortcut {
        sequence: "Ctrl+Shift+S"
        onActivated: {
            var timerCount = Object.keys(activeTimers).length
            var pendingCount = pendingTimerCleanup.length
            // console.log("[NotificationOverlay] Active timers:", timerCount, "Pending cleanup:", pendingCount)
            // console.log("[NotificationOverlay] Active timer IDs:", Object.keys(activeTimers))
        }
    }
    
    // Test shortcut for auto-dismiss fix validation
    Shortcut {
        sequence: "Ctrl+Shift+T"
        onActivated: testAutoDismissFix()
    }
    
    // FIXED: Test shortcut for consecutive NOTIFY_WARNING functionality
    Shortcut {
        sequence: "Ctrl+Shift+X"
        onActivated: testCloseButton()
    }
    
    // FIXED: Test function for close button functionality with consecutive NOTIFY_WARNING calls
    function testCloseButton() {
        if (!notificationManagerInstance) {
            // console.log("[NotificationOverlay] Cannot test - no notification manager instance")
            return
        }
        
        // console.log("[NotificationOverlay] === TESTING CONSECUTIVE NOTIFY_WARNING FUNCTIONALITY ===")
        // console.log("[NotificationOverlay] Timer debugging enabled: Watch for synchronization issues")
        timerDebugEnabled = 1
        
        // FIXED: Test the exact scenario mentioned in the issue
        // console.log("[NotificationOverlay] Creating consecutive NOTIFY_WARNING calls as reported in the issue...")
        
        notificationManagerInstance.warning("ZonalECU", "VIP (Vehicle Integration Platform) ~ OFFLINE")
        notificationManagerInstance.warning("ZonalECU", "VIP (Vehicle Integration Platform) ~ OFFLINE 1")
        notificationManagerInstance.warning("ZonalECU", "VIP (Vehicle Integration Platform) ~ OFFLINE 2")
        notificationManagerInstance.warning("ZonalECU", "VIP (Vehicle Integration Platform) ~ OFFLINE 3")
        notificationManagerInstance.warning("ZonalECU", "VIP (Vehicle Integration Platform) ~ OFFLINE 4")
        
        // console.log("[NotificationOverlay] ============================================")
        // console.log("[NotificationOverlay] INSTRUCTIONS FOR TESTING:")
        // console.log("[NotificationOverlay] 1. Watch for 5 consecutive warning notifications")
        // console.log("[NotificationOverlay] 2. All notifications should appear and auto-dismiss properly")
        // console.log("[NotificationOverlay] 3. Try clicking close buttons - they should work without errors")
        // console.log("[NotificationOverlay] 4. No 'not found for dismissal' warnings should appear")
        // console.log("[NotificationOverlay] 5. Check active timer count in console output")
        // console.log("[NotificationOverlay] ============================================")
        
        // Show timer status after creation
        Qt.callLater(function() {
            var timerCount = Object.keys(activeTimers).length
            var statusCount = Object.keys(notificationStatuses).length
            // console.log("[NotificationOverlay] Created", timerCount, "active timers")
            // console.log("[NotificationOverlay] Tracking", statusCount, "notification statuses")
            // console.log("[NotificationOverlay] Timer IDs:", Object.keys(activeTimers))
        }, 1000)
        
        // Check timer cleanup after some dismissals
        Qt.callLater(function() {
            var timerCount = Object.keys(activeTimers).length
            var statusCount = Object.keys(notificationStatuses).length
            // console.log("[NotificationOverlay] After 10 seconds - Active timers:", timerCount, "Statuses:", statusCount)
            if (timerCount === 0 && statusCount === 0) {
                // console.log("[NotificationOverlay] SUCCESS: All timers and statuses cleaned up properly")
            } else {
                // console.log("[NotificationOverlay] Remaining timer IDs:", Object.keys(activeTimers))
                // console.log("[NotificationOverlay] Remaining status IDs:", Object.keys(notificationStatuses))
            }
        }, 10000)
    }
}