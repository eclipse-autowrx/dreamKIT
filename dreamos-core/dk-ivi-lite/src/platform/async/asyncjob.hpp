// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#pragma once
#include <QObject>
#include <QFuture>
#include <QFutureWatcher>
#include <QtConcurrent>
#include <functional>
#include <type_traits>

namespace Async {

/* ------------------------------------------------------------------ */
/* 0) meta-object base                                                */
/* ------------------------------------------------------------------ */
class JobBase : public QObject
{
    Q_OBJECT
public:
    explicit JobBase(QObject *p = nullptr) : QObject(p) {}
signals:
    void finished(bool ok);
};

/* ------------------------------------------------------------------ */
/* 1) Generic job  (T != void)                                         */
/* ------------------------------------------------------------------ */
template<class T>
class Job : public JobBase
{
public:
    using Fn = std::function<T()>;

    explicit Job(Fn fn, QObject *parent = nullptr)
        : JobBase(parent)
    {
        m_future  = QtConcurrent::run(std::move(fn));
        m_watcher.setFuture(m_future);

        connect(&m_watcher, &QFutureWatcher<T>::finished,
                this,
                [this]() {
            bool ok = true;
            try {
                m_result = m_future.result();      // may throw
            } catch (...) {
                ok = false;
            }
            emit finished(ok);
        });
    }

    T result() const { return m_result; }

private:
    QFuture<T>          m_future;
    QFutureWatcher<T>   m_watcher;
    T                   m_result {};
};

/* ------------------------------------------------------------------ */
/* 1b) Specialisation for void                                        */
/* ------------------------------------------------------------------ */
template<>
class Job<void> : public JobBase
{
public:
    using Fn = std::function<bool()>;

    /*  internal: ctor is fed by Chain with a wrapper that *always*
     *  returns bool (true = success, false = failure)               */
    explicit Job(Fn fn, QObject *parent = nullptr)
        : JobBase(parent)
    {
        m_future  = QtConcurrent::run(std::move(fn));   // bool future
        m_watcher.setFuture(m_future);

        connect(&m_watcher, &QFutureWatcher<bool>::finished,
                this,
                [this]() {
            const bool ok = m_future.result();
            emit finished(ok);
        });
    }

private:
    QFuture<bool>        m_future;
    QFutureWatcher<bool> m_watcher;
};

/* ------------------------------------------------------------------ */
/* 2) Sequential chain                                                */
/* ------------------------------------------------------------------ */
class Chain : public QObject
{
    Q_OBJECT
public:
    /* --------------------------------------------------------------
     *  add() accepts any lambda/functor that returns void OR bool
     * ----------------------------------------------------------- */
    template<typename F>
    void add(F fn)
    {
        /* Wrapper converts the user's return value / exceptions
         * into a plain bool for Job<void>.                         */
        auto wrapper = [fn]() -> bool {
            using Result = std::invoke_result_t<F>;
            try {
                if constexpr (std::is_same_v<Result, void>) {
                    fn();                  // user code
                    return true;
                } else {                   // must be bool
                    static_assert(std::is_same_v<Result, bool>,
                                  "Chain::add(): functor must return void or bool");
                    return fn();           // true / false
                }
            } catch (...) {
                return false;              // any throw  -> failure
            }
        };

        m_fns << std::move(wrapper);
    }

    explicit Chain(QObject *p = nullptr) : QObject(p) {}

    void start()
    {
        if (m_idx >= m_fns.size()) {
            emit finished(true);
            return;
        }
        auto *job = new Job<void>(m_fns[m_idx], this);
        connect(job, &JobBase::finished,
                this,
                [this](bool ok){
            if (!ok) {
                emit finished(false);      // abort entire chain
                return;
            }
            ++m_idx;
            start();
        });
    }

signals:
    void finished(bool ok);

private:
    QList<std::function<bool()>> m_fns;    // list of wrapped steps
    int                           m_idx {0};
};

} // namespace Async
