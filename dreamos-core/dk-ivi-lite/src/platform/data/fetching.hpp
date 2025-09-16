// Copyright (c) 2025 Eclipse Foundation.
// 
// This program and the accompanying materials are made available under the
// terms of the MIT License which is available at
// https://opensource.org/licenses/MIT.
// 
// SPDX-License-Identifier: MIT
#ifndef MPFETCHING_H
#define MPFETCHING_H

#include <QString>

// bool queryMarketplacePackages(int page = 1, int limit = 10, const QString &category = "vehicle");
bool queryMarketplacePackages(const QString &marketplace_url, const QString &token = "", int page = 1, int limit = 10, const QString &category = "vehicle");
QString marketplace_login(const QString &login_url, const QString &username, const QString &password);

#endif //MPFETCHING_H
