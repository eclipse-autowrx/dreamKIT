#ifndef UNSAFEPARAMCHECK_H
#define UNSAFEPARAMCHECK_H

#include <QString>

QString getSafeDockerParam(QString runtimecfgFile);
QString getAudioParam(QString runtimecfgFile);
QString getUiParam(QString runtimecfgFile);
QString getSpecialParam(QString runtimecfgFile);

#endif //UNSAFEPARAMCHECK_H
