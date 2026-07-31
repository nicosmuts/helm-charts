{{/*
Expand the chart name.
*/}}
{{- define "avalonhome-prometheus-exporter.name" -}}
{{- default .Chart.Name .Values.nameOverride | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Create a fully qualified application name.
*/}}
{{- define "avalonhome-prometheus-exporter.fullname" -}}
{{- if .Values.fullnameOverride }}
{{- .Values.fullnameOverride | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- $name := default .Chart.Name .Values.nameOverride }}
{{- if contains $name .Release.Name }}
{{- .Release.Name | trunc 63 | trimSuffix "-" }}
{{- else }}
{{- printf "%s-%s" .Release.Name $name | trunc 63 | trimSuffix "-" }}
{{- end }}
{{- end }}
{{- end }}

{{/*
Chart label.
*/}}
{{- define "avalonhome-prometheus-exporter.chart" -}}
{{- printf "%s-%s" .Chart.Name .Chart.Version | replace "+" "_" | trunc 63 | trimSuffix "-" }}
{{- end }}

{{/*
Immutable selector labels.
*/}}
{{- define "avalonhome-prometheus-exporter.selectorLabels" -}}
app.kubernetes.io/name: {{ include "avalonhome-prometheus-exporter.name" . }}
app.kubernetes.io/instance: {{ .Release.Name }}
{{- end }}

{{/*
Common labels.
*/}}
{{- define "avalonhome-prometheus-exporter.labels" -}}
helm.sh/chart: {{ include "avalonhome-prometheus-exporter.chart" . }}
{{ include "avalonhome-prometheus-exporter.selectorLabels" . }}
app.kubernetes.io/version: {{ .Chart.AppVersion | quote }}
app.kubernetes.io/managed-by: {{ .Release.Service }}
{{- with .Values.commonLabels }}
{{ toYaml . }}
{{- end }}
{{- end }}

{{/*
Service account name.
*/}}
{{- define "avalonhome-prometheus-exporter.serviceAccountName" -}}
{{- if .Values.serviceAccount.create }}
{{- default (include "avalonhome-prometheus-exporter.fullname" .) .Values.serviceAccount.name }}
{{- else }}
{{- default "default" .Values.serviceAccount.name }}
{{- end }}
{{- end }}

{{/*
Image reference. A digest takes precedence over the tag.
*/}}
{{- define "avalonhome-prometheus-exporter.image" -}}
{{- if .Values.image.digest }}
{{- printf "%s@%s" .Values.image.repository .Values.image.digest }}
{{- else }}
{{- printf "%s:%s" .Values.image.repository .Values.image.tag }}
{{- end }}
{{- end }}

{{/*
Comma-separated miner host list for AVALON_IPS.
*/}}
{{- define "avalonhome-prometheus-exporter.avalonIPs" -}}
{{- join "," .Values.config.avalonIPs }}
{{- end }}
