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