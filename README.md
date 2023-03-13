# Нативный способ шифрования данных в Helm

Хочу поделиться решением задачи шифрования чувствительных данных в Helm, использующим встроенные функции encryptAES/decryptAES.

В Helm используется библиотека Go шаблонов [Sprig](https://github.com/Masterminds/sprig). Sprig сильно расширяет возможности динамической шаблонизации Helm, добавляя более 70 полезных функций. Основными функциями в реализации нативного шифрования являются encryptAES/decryptAES. Данные функции написаны на Go с помощью пакета crypto/aes и используют алгоритм шифрования AES-256 CBC.

### FYI Первое появление
Функции AES добавлены в релизе [Sprig v2.21.10](https://github.com/Masterminds/sprig/releases/tag/v2.21.0). В Helm функции стали доступны впервые в релизе [2.16.0](https://github.com/helm/helm/releases/tag/v2.16.0). В те же даты произошел первый релиз [Helm 3](https://github.com/helm/helm/releases/tag/v3.0.0) мажорной версии. Начиная с helm версий ^3.0.0 используется библиотека Sprig v3.0.0 уже с поддержкой функций AES. 

### FYI AES методы
У алгоритма AES есть 5 методов: 
- ECB (Electronic Code Book)
- CBC (Cipher Block Chaining)
- CFB (Cipher FeedBack)
- OFB (Output FeedBack)
- CTR (Counter)

Ознакомиться с ними можно тут: https://www.highgo.ca/2019/08/08/the-difference-in-five-modes-in-the-aes-encryption-algorithm/ 

В решении используется метод CBC: В этом режиме, если мы будем шифровать один и тот же блок текста **N** раз, мы получим **N** разных блоков зашифрованного текста.

# Практическая часть
Функция encryptAES возвращает base64 зашифрованную строку, что позволяет хранить чувствительные данные в git для комфортной работы с чартами. Работа с зашифрованными строками в git'е (коммиты с добавлением новых строк, пулл реквесты с изменением строк) не будут влиять на весь остальной файл. Изменения будут читабельными и не перегруженными. 

## Знакомимся с работой функции encryptAES. 
На вход функция принимает мастер ключ, который используется для шифрования алгоритмом AES-256 CBC, и строку. Функция так же умеет работать со строкой, передаваемой с помощью пайплайна (`|`).
```yaml
ENCRYPTED: {{ encryptAES "secretkey" "plaintext" }}
# ENCRYPTED: ELBF23ZmWwcneWKjWkdzFvGOKSzURIXxHyDczeFuh/M=

ENCRYPTED: {{ "plaintext" | encryptAES "secretkey"  }}
# ENCRYPTED: 3tYCDyVCb4yzfc/QkHhOP8F1qT7uc5fvcoJdkRAtRb4=
```

Функция decryptAES на вход принимает мастер ключ и зашифрованную с помощью алогоритма AES-256 CBC строку. Данная функция тоже умеет работать в режиме пайплайна с зашифрованной строкой.
```yaml
DECRYPTED: {{ decryptAES "secretkey" "ELBF23ZmWwcneWKjWkdzFvGOKSzURIXxHyDczeFuh/M=" }}
# DECRYPTED: plaintext

DECRYPTED: {{ "3tYCDyVCb4yzfc/QkHhOP8F1qT7uc5fvcoJdkRAtRb4=" | decryptAES "secretkey"  }}
# DECRYPTED: plaintext
```
На примерах выше мы шифровали одну и ту же строку, а получили разные значения на выходе. Это одна из особенностей алгоритма AES-256 CBC. 

## Пишем чарт для локального шифрования данных
Для шифрования значений и комфортной работы с зашифрованными значениями предлагаю написать чарт-утилиту, который будет использоваться для локального шифрования/дешифрования данных.
Входные переменные будем отражать в локальном `values.yaml`, а полученный результат после шифрования забирать после локального рендера чарта. 

### Файловая структура чарта
Файловая структура чарта содержит обязательный `Chart.yaml`, локальный `values.yaml` c манифестом `func.yaml`, который мы будем рендерить, и файл-хелпер `_helpers.tpl`, содержащий наши кастомные функции. 
```
./practice/encrypter-decrypter-v1
├── Chart.yaml
├── templates
│   ├── _helpers.tpl
│   └── func.yaml
└── values.yaml
```

Локальный `values.yaml` содержит мастер ключ в переменной `AESKey` и два словаря `encrypt` и `decrypt`. Словарь `encrypt` используется для шифрования значений, в него мы помещаем значения в формате `ключ: значение`. Словарь `decrypt`, куда мы помещаем значения в формате `ключ: зашифрованное значение`, используется для дешифрования значений.

`./practice/encrypter-decrypter-v1/values.yaml:`
```yaml
AESKey: bfc9cee25938d0f7f217b717

encrypt:
  key1: value1
  key2: value2
  key3: value3

decrypt:
  key1: 0ebxEl0zHruF4/bwup739KOXhqLKk/o47quuthoDwCQ=
  key2: 8FFxWu3QC2rxuuz8RT8qvXVzpKFSe2D1dJVo1SeB4mo=
  key3: 6zvZHud/3t9x+r7OVFM0+7SHBFNx5Ej6CPSjNmc15Rw=
```

Файл-хелпер `_helpers.tpl` определяет внутри себя две функции `encrypter` и `decrypter`. Обе функции работают по одному принципу:
- На вход первым параметром принимают мастер ключ в переменную `$aesKey`
- На вход вторым параметром принимают словарь значений формата `key: value` в переменную `$vallist`
- После чего по словарю проходит цикл и значения `value` попадают в переменную `$val` и шифруются в функции `encrypter`/дешифруются в функции `decrypter`
- Значения выводятся в формате `key: зашифрованное/дешифрованное value`

`./practice/encrypter-decrypter-v1/templates/_helpers.tpl:`
```yaml
{{/* Функция для шифрования переменных */}}
{{- define "encrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- range $key, $val := $vallist }}
{{ $key }}: {{ $val | encryptAES $aesKey }}
{{- end }}
{{- end -}}


{{/* Функция для дешифрования переменных */}}
{{- define "decrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- range $key, $val := $vallist }}
{{ $key }}: {{ $val | decryptAES $aesKey }}
{{- end -}}
{{- end -}}
```

Манифест `func.yaml` используется для рендера зашифрованных и дешифрованных значений с помощью функций определенных в файле-хелпере `_helpers.tpl`. В начале манифеста определяется переменная `$AESKey`, забирающая значение мастер ключа из локального `values.yaml`. В функцию `encrypter` передается словарь `encrypt`, а в функцию `decrypter` словарь `decrypt` из локального `values.yaml`.

`./practice/encrypter-decrypter-v1/templates/func.yaml:`
```yaml
{{- $AESKey := .Values.AESKey -}}

ENCRYPTED: VALUES
{{- include "encrypter" (list $AESKey .Values.encrypt) }}
DECRYPTED: VALUES
{{- include "decrypter" (list $AESKey .Values.decrypt) }}
```

### Используем чарт

После определения значений для шифрования/дешифрования в локальном `values.yaml` в словарях `encrypt` и `decrypt`, необходимо зарендерить манифест `func.yaml` для получения зашифрованных/дешифрованных значений.
```console
helm template ./practice/encrypter-decrypter-v1   
```
Получаем следующий результат:
```yaml
# Source: encrypter-decrypter/templates/func.yaml
ENCRYPTED: VALUES
key1: JDsKiDyvCsWMMZQaX0ntaQ8zA/Zg4b9CnOrhTYpXbEQ=
key2: skap9TMkq3m2w6A1bUOEFfMC0fs/Uc5DKHbHYm2G6E0=
key3: 7zzQaBcOsuARBEISWOrpo8UEEElhMst44J9v0esW6As=
DECRYPTED: VALUES
key1: value1
key2: value2
key3: value3
```

## Улучшаем чарт

Предлагаю добавить префикс для идентификации значений, зашифрованных с помощью функции encryptAES. Для этого изменим функции `encrypter` и `decrypter` в файле-хелпере `_helpers.tpl`.

`./practice/encrypter-decrypter-v2/templates/_helpers.tpl:`
```yaml
{{/* Функция для шифрования переменных с добавлением ID,
состоящего из AES256*/}}
{{- define "encrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- $CommonID :=  printf "%s:" "AES256" }}
{{- range $key, $val := $vallist }}
{{ $key }}: {{$CommonID}}{{ $val | encryptAES $aesKey }}
{{- end }}
{{- end -}}


{{/* Функция для дешифрования переменных с добавлением ID,
состоящего из AES256*/}}
{{- define "decrypter" -}}
{{- $aesKey := index . 0 }}
{{- $vallist := index . 1 }}
{{- $CommonID :=  printf "%s:" "AES256" }}
{{- range $key, $val := $vallist }}
{{- if hasPrefix $CommonID $val }}
{{ $key }}: {{ ( trimPrefix $CommonID  $val) | decryptAES $aesKey }}
{{- else }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}
{{- end -}}
```

Теперь к зашифрованному значению на выходе будет добавляться `$CommonID`, состоящий из строки `AES256:`. А при дешифровании функция `decrypter` будет проверять наличие префикса `$CommonID` и расшифровывать значение при успешной проверке.

Рассмотрим на примере нового локального `values.yaml`.

`./practice/encrypter-decrypter-v2/values.yaml:`
```yaml
AESKey: bfc9cee25938d0f7f217b717

encrypt:
  key1: value1
  key2: value2
  key3: value3

decrypt:
  key1: 0ebxEl0zHruF4/bwup739KOXhqLKk/o47quuthoDwCQ=
  key2: AES256:8FFxWu3QC2rxuuz8RT8qvXVzpKFSe2D1dJVo1SeB4mo=
  key3: AES256:6zvZHud/3t9x+r7OVFM0+7SHBFNx5Ej6CPSjNmc15Rw=
```

Заренденрим чарт:
```console
helm template ./practice/encrypter-decrypter-v2
```
Получаем следующий результат:
```yaml
# Source: encrypter-decrypter/templates/func.yaml
ENCRYPTED: VALUES
key1: AES256:qMd/MQDKx7Yn1k4SnfdWGFeUZUooNWy7c8Sv7nhaGUY=
key2: AES256:8Lh/sBMfBewN0vwKBiwqt/PwLpl5nEhgi3Jj8L+7FLA=
key3: AES256:QUshXwAdEIlu69esOllVIdTtQRMLFNG6K2NSt9d/Bgw=
DECRYPTED: VALUES
key1: 0ebxEl0zHruF4/bwup739KOXhqLKk/o47quuthoDwCQ=
key2: value2
key3: value3
```

## Применяем нативное шифрование на примере

Создадим чарт с акцентом на сущность типа Secret, который предназначен для хранения чувстительных данных в Kubernetes.
```
./practice/pseudo-service-v1
├── Chart.yaml
├── templates
│   ├── _helpers.tpl
│   └── secret.yaml
└── values.yaml
```

В файл-хелпер `_helpers.tpl` перенесем только функцию `decrypter`, так как для чартов сервисов **не требуется** функционал шифрования данных.
Для примера, в локальный `values.yaml` я добавил зашифрованный пароль от суперпользователя БД вместе с не зашифрованными значениями хоста и суперпользователя.

`./practice/pseudo-service-v1/values.yaml:`
```yaml
decrypt:
  DB_HOST: postgresql:5432
  DB_USER: postgres
  DB_PASS: AES256:M2hLbaafTNvC5sNz9m58d4gH7pSFHB2ilVPScw2QS57Cd0/vrO+WR/nbkYUl/Nvh
```

Сущность типа Secret вызывает уже известную нам функцию `decrypter`. В функцию передается мастер ключ `AESKey` и словарь `decrypt` из локального `values.yaml`. 

`./practice/pseudo-service-v1/templates/secret.yaml:`
```yaml
apiVersion: v1
kind: Secret
metadata:
  name: pseudo-secret
type: Opaque
stringData:
{{- include "decrypter" (list .Values.AESKey .Values.decrypt) | indent 2 -}}
```

Стоит обратить внимание на подход с передачей мастер ключа `AESKey`. Поскольку мы не храним мастер ключ в чарте сервиса, при попытке локального рендера чарта хелм будет ругаться на пустую переменную `.Values.AESKey:

```console
helm template ./practice/pseudo-service-v1
```
Получаем следующий результат:
```yaml
Error: template: Pseudo-Service/templates/secret.yaml:7:4: executing "Pseudo-Service/templates/secret.yaml" at <include "decrypter" (list .Values.AESKey .Values.decrypt)>: error calling include: template: Pseudo-Service/templates/_helpers.tpl:9:58: executing "decrypter" at <$aesKey>: invalid value; expected string

Use --debug flag to render out invalid YAML
```

Поэтому для корректного локального рендера и последующего развертывания чарта в Kubernetes, будем передавать мастер ключ в рантайме:

```console
helm template ./practice/pseudo-service-v1 --set AESKey=bfc9cee25938d0f7f217b717
```
Получаем следующий результат:
```yaml
# Source: Pseudo-Service/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: pseudo-secret
type: Opaque
stringData:  
  DB_HOST: postgresql:5432
  DB_PASS: MyUniquePassword
  DB_USER: postgres
```

## Улучшаем локальную работу с шифрованием

Постоянно передавать мастер ключ в рантайме при локальной разработке и обновления чарта не удобно, поэтому предлагаю генерировать префикс зашифрованных значений по другому правилу.

`./practice/encrypter-decrypter-v3/templates/_helpers.tpl:`
```yaml
{{/* Функция для шифрования переменных с добавлением ID,
состоящего из контура и AES256*/}}
{{- define "encrypter" -}}
{{- $aesKey := index . 0 }}
{{- $contour := index . 1 }}
{{- $vallist := index . 2 }}
{{- $CommonID :=  printf "%s:%s:" $contour "AES256" }}
{{- range $key, $val := $vallist }}
{{ $key }}: {{$CommonID}}{{ $val | encryptAES $aesKey }}
{{- end }}
{{- end -}}


{{/* Функция для дешифрования переменных с добавлением ID,
состоящего из контура и AES256*/}}
{{- define "decrypter" -}}
{{- $aesKey := index . 0 }}
{{- $contour := index . 1 }}
{{- $vallist := index . 2 }}
{{- $CommonID :=  printf "%s:%s:" $contour "AES256" }}
{{- range $key, $val := $vallist }}
{{- if hasPrefix $CommonID $val }}
{{ $key }}: {{ ( trimPrefix $CommonID  $val) | decryptAES $aesKey }}
{{- else }}
{{ $key }}: {{ $val }}
{{- end }}
{{- end -}}
{{- end -}}
```

Теперь функции имеют новый входной параметр `$contour`. Данный параметр отвечает за контур для которого шифруется значения *(например, `dev/test/prod`)*.
Параметр используется в `$CommonID` для генерации префикса формата `$contour:AES256:`. При дешифровании функция `decrypter` также будет проверять наличие префикса `$CommonID` и расшифровывать значение при успешной проверке.

Обновленный values.yaml выглядит следующим образом.

`./practice/encrypter-decrypter-v3/values.yaml:`
```yaml
AESKey: bfc9cee25938d0f7f217b717
contour: test

encrypt:
  key1: value1
  key2: value2
  key3: value3

decrypt:
  key1: 0ebxEl0zHruF4/bwup739KOXhqLKk/o47quuthoDwCQ=
  key2: test:AES256:8FFxWu3QC2rxuuz8RT8qvXVzpKFSe2D1dJVo1SeB4mo=
  key3: test:AES256:6zvZHud/3t9x+r7OVFM0+7SHBFNx5Ej6CPSjNmc15Rw=
```

Заренденрим чарт:
```console
helm template ./practice/encrypter-decrypter-v3
```
Получаем следующий результат:
```yaml
# Source: encrypter-decrypter/templates/func.yaml
ENCRYPTED: VALUES
key1: test:AES256:VO9qi89SGvHXT9lGijJY3RNWRQnH0VH0A62YlRqbdO4=
key2: test:AES256:zgqIK+ujJtPGbIuw5Qw5u7my7aggPDiIIZVVzQ37E7Y=
key3: test:AES256:FbNu5u/eUiD2vZU6jfDFV6udQLQOnKmTwwkgKyaygtY=
DECRYPTED: VALUES
key1: 0ebxEl0zHruF4/bwup739KOXhqLKk/o47quuthoDwCQ=
key2: value2
key3: value3
```

Вернемся к нашему примеру чарта сервиса, в котором обновленный локальный `values.yaml` уже содержит переменную `contour`.

`./practice/pseudo-service-v2/values.yaml:`
```yaml
contour: test

decrypt:
  DB_HOST: postgresql:5432
  DB_USER: postgres
  DB_PASS: test:AES256:Zj0+Ba5PcsHPAUp2I/ivHTT7CusMNij3scz/WyEHvKu3wLlM4hNMpnXWXQ5IY0Ou
```

В такой конфигурации мы можем не передавать мастер ключ в рантайме, а динамически переопределять контур для которого рендерится чарт.

```console
helm template ./practice/pseudo-service-v2 --set contour=local
```
Получаем следующий результат:
```yaml
# Source: Pseudo-Service/templates/secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: pseudo-secret
type: Opaque
stringData:  
  DB_HOST: postgresql:5432
  DB_PASS: test:AES256:Zj0+Ba5PcsHPAUp2I/ivHTT7CusMNij3scz/WyEHvKu3wLlM4hNMpnXWXQ5IY0Ou
  DB_USER: postgres
```

После переопределения контура чарт ренедрится с зашифрованными значениями, что позволяет комфортно заниматься разработкой чарта и не отвлекаться на подстановку мастер ключа на каждый локальный рендер чарта.

# Заключение
Данное решение задачи шифрования чувствительных данных позволяет избежать хранения чувствительных данных в репозитории с чартами. С помощью встроенных функций Helm и файлов-хелперов это решение легко встраивается в Cd процессы.