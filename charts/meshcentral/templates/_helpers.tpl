{{- define "meshcentral.name" -}}
{{- .Chart.Name }}
{{- end }}

{{- define "meshcentral.fullname" -}}
{{- if contains .Chart.Name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name .Chart.Name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}

{{- define "meshcentral.labels" -}}
helm.sh/chart: {{ printf "%s-%s" .Chart.Name .Chart.Version }}
{{ include "meshcentral.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- end }}

{{- define "meshcentral.selectorLabels" -}}
app.kubernetes.io/name: {{ include "meshcentral.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{- define "meshcentral.image" -}}
{{- printf "%s/%s:%s" .Values.image.registry .Values.image.repository .Values.image.tag }}
{{- end }}

{{/* Reprend une clé d'un Secret existant de la release, sinon génère une valeur aléatoire */}}
{{- define "meshcentral.keepOrRandom" -}}
{{- $secret := lookup "v1" "Secret" .ctx.Release.Namespace .name }}
{{- if and $secret $secret.data (index $secret.data .key) }}
{{- index $secret.data .key | b64dec }}
{{- else }}
{{- randAlphaNum .length }}
{{- end }}
{{- end }}

{{- define "meshcentral.adminPassword" -}}
{{- .Values.admin.password | default (include "meshcentral.keepOrRandom" (dict "ctx" . "name" (printf "%s-admin" (include "meshcentral.fullname" .)) "key" "password" "length" 24)) }}
{{- end }}

{{- define "meshcentral.sessionKey" -}}
{{- include "meshcentral.keepOrRandom" (dict "ctx" . "name" (printf "%s-config" (include "meshcentral.fullname" .)) "key" "sessionkey" "length" 64) }}
{{- end }}

{{/* config.json : TLS terminé par l'Ingress, MeshCentral en HTTP sur 4430, base NeDB */}}
{{- define "meshcentral.config" -}}
{{- $hostname := required "hostname est requis" .Values.hostname }}
{{- $settings := dict
  "cert" $hostname
  "port" 4430
  "aliasport" 443
  "redirport" 0
  "tlsoffload" true
  "trustedproxy" true
  "sessionkey" (include "meshcentral.sessionKey" .)
  "selfupdate" false
  "agentpong" 300
-}}
{{- $domain := dict
  "certurl" (printf "https://%s:443/" $hostname)
  "newaccounts" false
  "hide" 5
  "devicesearchbarserverandclientname" true
  "devicesearchbargroupname" true
  "hidepowertimeline" true
  "agenttag" (dict "servertags" 1 "serverdesc" 1)
-}}
{{- with .Values.ui.title }}{{ $_ := set $domain "title" . }}{{ end }}
{{- $config := dict
  "$schema" "https://raw.githubusercontent.com/Ylianst/MeshCentral/master/meshcentral-config-schema.json"
  "settings" $settings
  "domains" (dict "" $domain)
-}}
{{- mustMergeOverwrite $config (deepCopy .Values.config) | toPrettyJson }}
{{- end }}
