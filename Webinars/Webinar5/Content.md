# Live 5 — Ingress no Minikube: rota bonita e host

Objetivo da live: dominar **Ingress** no Kubernetes, aprendendo a **expor aplicações com URLs amigáveis**, **configurar roteamento por path e host**, **habilitar o Ingress Controller** no Minikube e construir uma arquitetura com **roteamento inteligente** (web + api atrás do Ingress).

**Entregável:** aplicação multi-serviço acessível via URLs amigáveis sem NodePort, usando Ingress para roteamento inteligente.

---

## Pré-requisitos

✅ **Cluster Minikube ativo:**

```bash
minikube status
```

**Importante:** Se o cluster estiver parado, inicie-o:

```bash
minikube start --driver=docker
```

Verificar que está funcionando:

```bash
kubectl get nodes
```

Esperado: 1 node com status `Ready`.

✅ **Docker Hub Account:**

Você precisará de uma conta no Docker Hub para fazer push da imagem. Se não tiver:
- Criar conta em: https://hub.docker.com
- Fazer login local: `docker login`

✅ **Ingress Controller (será habilitado durante a live)**

**📝 Nota importante para macOS + Docker driver:**

No macOS usando o driver Docker, o IP do Minikube (obtido com `minikube ip`) geralmente não está acessível diretamente do host. Para testar o Ingress sem configurar `/etc/hosts`, você pode usar o túnel automático do Minikube:

```bash
# Obter URL do Ingress Controller (cria túnel automático)
INGRESS_URL=$(minikube service -n ingress-nginx ingress-nginx-controller --url)

# Usar nos testes
curl -H "Host: myapp.local" $INGRESS_URL/api/health
```

Esta abordagem funciona sem precisar editar `/etc/hosts` e é especialmente útil para testes rápidos.

---

## O que vamos aprender

1. **O que é Ingress** - roteamento de tráfego HTTP/HTTPS
2. **Ingress Controller** - NGINX Ingress no Minikube
3. **Roteamento por Path** - `/` e `/api`
4. **Roteamento por Host** - `myapp.local` e `api.myapp.local`
5. **Annotations** - configurações avançadas do NGINX
6. **TLS/HTTPS** - certificados SSL (opcional)
7. **Arquitetura production-ready** - sem NodePort, só ClusterIP + Ingress
---

## 1) Entendendo Ingress no Kubernetes

### O que é Ingress?

Nas lives anteriores, usamos **NodePort** para expor aplicações externamente. Mas NodePort tem limitações:
- ❌ Portas altas (30000-32767) - não são user-friendly
- ❌ Sem roteamento inteligente (path, host, headers)
- ❌ Sem terminação SSL/TLS centralizada
- ❌ Um service = uma porta diferente

**Ingress resolve tudo isso!**

### O que é um Ingress?

**Ingress** é um recurso do Kubernetes que gerencia **acesso externo** aos serviços do cluster, tipicamente HTTP/HTTPS.

**Funcionalidades:**
- ✅ **Roteamento por path**: `/` → webapp, `/api` → api
- ✅ **Roteamento por host**: `myapp.local` → webapp, `api.myapp.local` → api
- ✅ **Terminação SSL/TLS**: HTTPS centralizado
- ✅ **URL amigáveis**: sem portas estranhas
- ✅ **Load balancing**: distribuição automática
- ✅ **Name-based virtual hosting**: múltiplos hosts no mesmo IP

### Ingress vs Service

| Recurso | Função | Exemplo |
|---------|--------|---------|
| **Service** | Expõe pods dentro ou fora do cluster | ClusterIP, NodePort, LoadBalancer |
| **Ingress** | Roteamento HTTP(S) inteligente | Path-based, Host-based routing |

**Analogia:**
- **Service** = Servidor web simples (Apache, IIS)
- **Ingress** = Reverse proxy inteligente (NGINX, Traefik, HAProxy)

### Componentes do Ingress

1. **Ingress Resource** (YAML): Regras de roteamento
2. **Ingress Controller**: Implementação que executa as regras (NGINX, Traefik, HAProxy, etc.)
3. **Services**: Backend que recebe o tráfego

**Fluxo:**

```
Internet → Ingress Controller (NGINX) → Ingress Rules → Services → Pods
```

---

## 2) Habilitando Ingress Controller no Minikube

O Minikube vem com um **addon de Ingress** (NGINX Ingress Controller) que pode ser habilitado facilmente.

### 2.1) Habilitar addon de Ingress

```bash
minikube addons enable ingress
```

**Saída esperada:**

```
🌟  The 'ingress' addon is enabled
```

### 2.2) Verificar o Ingress Controller

O addon cria recursos no namespace `ingress-nginx`:

```bash
kubectl get pods -n ingress-nginx
```

**Saída esperada:**

```
NAME                                        READY   STATUS      RESTARTS   AGE
ingress-nginx-admission-create-xxx          0/1     Completed   0          2m
ingress-nginx-admission-patch-xxx           0/1     Completed   0          2m
ingress-nginx-controller-xxxxxxxxxx-xxxxx   1/1     Running     0          2m
```

**Verificar serviços:**

```bash
kubectl get svc -n ingress-nginx
```

**Saída esperada:**

```
NAME                                 TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)
ingress-nginx-controller             NodePort    10.96.x.x       <none>        80:xxxxx/TCP,443:xxxxx/TCP
ingress-nginx-controller-admission   ClusterIP   10.96.x.x       <none>        443/TCP
```

✅ **Ingress Controller rodando!**

### 2.3) Verificar versão do Ingress Controller

```bash
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- /nginx-ingress-controller --version
```

---

## 3) Namespace e aplicações base

Vamos usar as mesmas aplicações da Live 4 (WebAPI e WebApp), mas agora com Ingress!

### namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webinar5
  labels:
    name: webinar5
    purpose: ingress-demo
```

Aplicar:

```bash
cd Webinars/Webinar5

kubectl apply -f namespace.yaml
```

---

## 4) Deployments e Services (ClusterIP apenas!)

Agora vamos usar **apenas ClusterIP** para os Services, pois o Ingress Controller fará o acesso externo.

### deployment.yaml (API)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapi
  namespace: webinar5
  labels:
    app: myapp-webapi
    tier: backend
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: myapp-webapi
  template:
    metadata:
      labels:
        app: myapp-webapi
        tier: backend
    spec:
      containers:
      - name: webapi
        image: <docker-hub-account>/myapp-webapi:3.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

### service-clusterip.yaml (API)

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-service
  namespace: webinar5
  labels:
    app: myapp-webapi
spec:
  type: ClusterIP  # Apenas interno - Ingress faz acesso externo
  selector:
    app: myapp-webapi
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
```

### deployment-webapp.yaml (Web)

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapp
  namespace: webinar5
  labels:
    app: myapp-webapp
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp-webapp
  template:
    metadata:
      labels:
        app: myapp-webapp
        tier: frontend
    spec:
      containers:
      - name: webapp
        image: <docker-hub-account>/myapp-webapp:1.0
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"
```

### service-webapp-clusterip.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapp-service
  namespace: webinar5
  labels:
    app: myapp-webapp
spec:
  type: ClusterIP  # Internal only - Ingress handles external access
  selector:
    app: myapp-webapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
```

**Aplicar tudo:**

```bash
kubectl apply -f deployment.yaml
kubectl apply -f service-webapi-clusterip.yaml
kubectl apply -f deployment-webapp.yaml
kubectl apply -f service-webapp-clusterip.yaml
```

**Verificar:**

```bash
kubectl get all -n webinar5
```

✅ Agora temos pods e services rodando, mas **sem acesso externo** (ainda).

---

## 5) Roteamento por Path (Path-based Routing)

Vamos criar um Ingress que roteia por **path**:
- `/` → WebApp
- `/api` → API

### ingress-path.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress-path
  namespace: webinar5
  annotations:
    nginx.ingress.kubernetes.io/use-regex: "true"
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
    - http:
        paths:
          # Frontend: tudo que NÃO começar com /api
          - path: /(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: myapp-webapp-service
                port:
                  number: 80
          
          # Backend: /api/<algo> -> /<algo> no service da API
          - path: /api(/|$)(.*)
            pathType: ImplementationSpecific
            backend:
              service:
                name: myapp-webapi-service
                port:
                  number: 80
```

**Explicação dos campos:**

- **ingressClassName**: Define qual controller usar (`nginx`)
- **annotations**:
  - `use-regex: "true"` = Habilita suporte a expressões regulares nos paths
  - `rewrite-target: /$2` = Usa o segundo grupo de captura da regex para reescrever o path
- **rules**: Lista de regras de roteamento
- **http.paths**: Caminhos e backends
- **path**: URL path com regex
  - `/(.*)` = Captura qualquer path (grupo 1 e 2)
  - `/api(/|$)(.*)` = Captura `/api/` ou `/api` seguido de qualquer coisa (grupo 2)
- **pathType**: `ImplementationSpecific` = Permite regex (específico do NGINX)
- **backend.service**: Service de destino e porta

**Como funciona o rewrite:**
- Requisição: `http://example.com/api/products`
- Regex match: `/api(/|$)(.*)` captura `/` (grupo 1) e `products` (grupo 2)
- Rewrite: `/$2` = `/products` (envia para o backend sem o prefixo `/api`)

**Aplicar:**

```bash
kubectl apply -f ingress-path.yaml
```

**Verificar:**

```bash
kubectl get ingress -n webinar5

# Ver detalhes
kubectl describe ingress myapp-ingress-path -n webinar5
```

**Saída esperada:**

```
NAME                  CLASS   HOSTS   ADDRESS        PORTS   AGE
myapp-ingress-path    nginx   *       192.168.49.2   80      10s
```

### 5.1) Testar roteamento por path

Obter IP do Minikube:

```bash
minikube ip
```

Testar no terminal:

```bash
MINIKUBE_IP=$(minikube ip)

# WebApp (root path)
curl http://${MINIKUBE_IP}/

# API health
curl http://${MINIKUBE_IP}/api/health

# API instance
curl http://${MINIKUBE_IP}/api/instance

# API products
curl http://${MINIKUBE_IP}/api/products
```

**📝 Nota para macOS + Docker driver:**

No macOS com Docker driver, o IP do Minikube pode não estar acessível diretamente. Neste caso, use o serviço do Ingress Controller:

```bash
# Obter URL do Ingress Controller
minikube service -n ingress-nginx ingress-nginx-controller --url

# Testar endpoints
curl -i $INGRESS_URL/
curl -i $INGRESS_URL/api/health
curl -i $INGRESS_URL/api/instance
curl -i $INGRESS_URL/api/products
```

Isso cria um túnel automático para o Ingress Controller, permitindo acessar os serviços sem configurar /etc/hosts.

🎉 **Funcionou! Roteamento por path!**

---

## 6) Roteamento por Host (Host-based Routing)

Agora vamos criar roteamento por **hostname** (virtual hosting):
- `myapp.local` → WebApp
- `api.myapp.local` → API

### ingress-host.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress-host
  namespace: webinar5
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-webapp-service
            port:
              number: 80
  - host: api.myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-webapi-service
            port:
              number: 80
```

**Diferenças:**

- Agora temos **host** definido em cada rule
- Cada host aponta para um service diferente
- Sem rewrite, pois cada serviço fica na raiz do seu domínio

**Aplicar:**

Primeiro, vamos deletar o ingress anterior:

```bash
kubectl delete ingress myapp-ingress-path -n webinar5
```

Aplicar o novo:

```bash
kubectl apply -f ingress-host.yaml
```

**Verificar:**

```bash
kubectl get ingress -n webinar5 -o wide
```

### 6.2) Configurar /etc/hosts

Para testar localmente, precisamos mapear os hostnames para o IP do Minikube:

```bash
MINIKUBE_IP=$(minikube ip)
echo "${MINIKUBE_IP} myapp.local api.myapp.local"
```

**Editar /etc/hosts** (requer sudo):

```bash
sudo nano /etc/hosts
```

Adicionar linha:

```
192.168.49.2 myapp.local api.myapp.local
```

Salvar (`Ctrl+O`, `Enter`, `Ctrl+X`).

### 6.3) Testar roteamento por host

**Terminal:**

```bash
# WebApp
curl http://myapp.local/

# API
curl http://api.myapp.local/health
curl http://api.myapp.local/instance
curl http://api.myapp.local/products
```

**📝 Nota para macOS + Docker driver:**

Se você não configurou /etc/hosts ou o IP não está acessível, use o túnel do Ingress Controller com header Host:

```bash
# Obter URL do Ingress Controller
INGRESS_URL=$(minikube service -n ingress-nginx ingress-nginx-controller --url)

# Testar com Host header
curl -H "Host: myapp.local" $INGRESS_URL/
curl -H "Host: api.myapp.local" $INGRESS_URL/health
curl -H "Host: api.myapp.local" $INGRESS_URL/instance
curl -H "Host: api.myapp.local" $INGRESS_URL/products
```

**Navegador:**

- http://myapp.local
- http://api.myapp.local/products

🎉 **Roteamento por host funcionando!**

---

## 7) Combinando Path + Host (Arquitetura Recomendada)

A arquitetura mais comum é **um domínio com paths diferentes**:
- `myapp.local/` → WebApp
- `myapp.local/api/*` → API

### ingress-combined.yaml

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: webinar5
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-webapp-service
            port:
              number: 80
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: myapp-webapi-service
            port:
              number: 80
```

**Entendendo o rewrite avançado:**

- **path**: `/api(/|$)(.*)` - regex que captura tudo depois de `/api`
- **rewrite-target**: `/$2` - usa o segundo grupo de captura (o que vem depois de `/api`)
- **Resultado**: 
  - `/api/products` → backend recebe `/products`
  - `/api/health` → backend recebe `/health`

**Aplicar:**

```bash
kubectl delete ingress myapp-ingress-host -n webinar5
kubectl apply -f ingress-combined.yaml
```

**Testar:**

```bash
# WebApp
curl http://myapp.local/

# API
curl http://myapp.local/api/health
curl http://myapp.local/api/instance
curl http://myapp.local/api/products
```

**📝 Nota para macOS + Docker driver:**

Se você não configurou /etc/hosts ou prefere usar o túnel automático:

```bash
# Obter URL do Ingress Controller
INGRESS_URL=$(minikube service -n ingress-nginx ingress-nginx-controller --url)

# Testar com Host header
curl -H "Host: myapp.local" $INGRESS_URL/
curl -H "Host: myapp.local" $INGRESS_URL/api/health
curl -H "Host: myapp.local" $INGRESS_URL/api/instance
curl -H "Host: myapp.local" $INGRESS_URL/api/products
```

🎉 **Arquitetura production-ready!**

---

## 8) Scripts de teste automatizados

Vamos criar scripts para facilitar os testes.

### test-ingress.sh

```bash
#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Ingress Endpoints${NC}"
echo -e "${BLUE}========================================${NC}\n"

# Get Minikube IP
MINIKUBE_IP=$(minikube ip)
echo -e "${YELLOW}Minikube IP: ${MINIKUBE_IP}${NC}\n"

echo -e "${GREEN}Testing Web App (myapp.local):${NC}\n"
curl -H "Host: myapp.local" http://${MINIKUBE_IP}/ -s -o /dev/null -w "Status: %{http_code}\n"
echo ""

echo -e "${GREEN}Testing API via /api path (myapp.local/api):${NC}\n"
echo -e "${YELLOW}Request #1:${NC}"
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/instance -s)
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}Error: No response from server${NC}"
else
  echo "$RESPONSE" | jq '.'
fi
echo ""

echo -e "${YELLOW}Request #2:${NC}"
RESPONSE=$(curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/instance -s)
if [ -z "$RESPONSE" ]; then
  echo -e "${RED}Error: No response from server${NC}"
else
  echo "$RESPONSE" | jq '.'
fi
echo ""

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "All requests are routed through the Ingress controller!"
echo -e "- Web App is accessible at: myapp.local/"
echo -e "- API is accessible at: myapp.local/api/*"
echo -e ""
echo -e "${YELLOW}To test in browser, add this to /etc/hosts:${NC}"
echo -e "  ${MINIKUBE_IP} myapp.local"
echo -e "${BLUE}========================================${NC}"
```

**Usar:**

```bash
chmod +x test-ingress.sh
./test-ingress.sh
```

**📝 Nota para macOS + Docker driver:**

Se o script test-ingress.sh não funcionar (porque o IP do Minikube não está acessível), você pode testar diretamente com o túnel do Ingress Controller:

```bash
# Obter URL do Ingress Controller
INGRESS_URL=$(minikube service -n ingress-nginx ingress-nginx-controller --url)

# Testar manualmente
curl -H "Host: myapp.local" -i $INGRESS_URL/
curl -H "Host: myapp.local" -i $INGRESS_URL/api/health
curl -H "Host: myapp.local" -i $INGRESS_URL/api/instance
curl -H "Host: myapp.local" -i $INGRESS_URL/api/products
```

Ou modifique o script `test-ingress.sh` para usar `$INGRESS_URL` em vez de `${MINIKUBE_IP}`.

---

## 9) Annotations importantes do NGINX Ingress

O NGINX Ingress suporta várias annotations para configurações avançadas:

### Rewrite e Redirect

```yaml
annotations:
  # Rewrite do path
  nginx.ingress.kubernetes.io/rewrite-target: /$2
  
  # Redirect permanente
  nginx.ingress.kubernetes.io/permanent-redirect: https://novo-site.com
  
  # Redirect temporário  
  nginx.ingress.kubernetes.io/temporal-redirect: https://manutencao.com
```

### CORS (Cross-Origin Resource Sharing)

```yaml
annotations:
  nginx.ingress.kubernetes.io/enable-cors: "true"
  nginx.ingress.kubernetes.io/cors-allow-methods: "GET, POST, PUT, DELETE, OPTIONS"
  nginx.ingress.kubernetes.io/cors-allow-origin: "*"
  nginx.ingress.kubernetes.io/cors-allow-credentials: "true"
```

### Rate Limiting

```yaml
annotations:
  nginx.ingress.kubernetes.io/limit-rps: "10"  # 10 requisições por segundo
  nginx.ingress.kubernetes.io/limit-connections: "5"  # 5 conexões simultâneas
```

### SSL/TLS

```yaml
annotations:
  nginx.ingress.kubernetes.io/ssl-redirect: "true"  # Force HTTPS
  nginx.ingress.kubernetes.io/force-ssl-redirect: "true"
```

### Timeout

```yaml
annotations:
  nginx.ingress.kubernetes.io/proxy-connect-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-send-timeout: "60"
  nginx.ingress.kubernetes.io/proxy-read-timeout: "60"
```

### Sticky Sessions (Session Affinity)

```yaml
annotations:
  nginx.ingress.kubernetes.io/affinity: "cookie"
  nginx.ingress.kubernetes.io/session-cookie-name: "route"
  nginx.ingress.kubernetes.io/session-cookie-max-age: "172800"  # 2 dias
```

---

## 10) All-in-One YAML

Para facilitar o deploy completo:

### all-in-one.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webinar5
  labels:
    name: webinar5
    purpose: ingress-demo

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapi
  namespace: webinar5
  labels:
    app: myapp-webapi
    tier: backend
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: myapp-webapi
  template:
    metadata:
      labels:
        app: myapp-webapi
        tier: backend
    spec:
      containers:
      - name: webapi
        image: <docker-hub-account>/myapp-webapi:3.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-service
  namespace: webinar5
  labels:
    app: myapp-webapi
spec:
  type: ClusterIP
  selector:
    app: myapp-webapi
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapp
  namespace: webinar5
  labels:
    app: myapp-webapp
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp-webapp
  template:
    metadata:
      labels:
        app: myapp-webapp
        tier: frontend
    spec:
      containers:
      - name: webapp
        image: <docker-hub-account>/myapp-webapp:1.0
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapp-service
  namespace: webinar5
  labels:
    app: myapp-webapp
spec:
  type: ClusterIP
  selector:
    app: myapp-webapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080

---
# Ingress with host-based routing and path rewrite
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: myapp-ingress
  namespace: webinar5
  annotations:
    nginx.ingress.kubernetes.io/rewrite-target: /$2
spec:
  ingressClassName: nginx
  rules:
  - host: myapp.local
    http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: myapp-webapp-service
            port:
              number: 80
      - path: /api(/|$)(.*)
        pathType: ImplementationSpecific
        backend:
          service:
            name: myapp-webapi-service
            port:
              number: 80
```

**Deploy completo:**

```bash
# ANTES: trocar '<docker-hub-account>' pelo seu usuário do Docker Hub

# Habilitar Ingress
minikube addons enable ingress

# Deploy tudo
kubectl apply -f all-in-one.yaml

# Aguardar pods ficarem prontos
kubectl get pods -n webinar5 -w

# Verificar Ingress
kubectl get ingress -n webinar5

# Adicionar ao /etc/hosts
MINIKUBE_IP=$(minikube ip)
echo "${MINIKUBE_IP} myapp.local" | sudo tee -a /etc/hosts

# Testar
curl http://myapp.local/
curl http://myapp.local/api/health
```

---

## 11) Comandos úteis de Ingress

### Listar Ingress

```bash
# Todos os namespaces
kubectl get ingress --all-namespaces

# Namespace específico
kubectl get ingress -n webinar5

# Com mais detalhes
kubectl get ingress -n webinar5 -o wide
```

### Descrever Ingress

```bash
kubectl describe ingress myapp-ingress -n webinar5
```

**O que observar:**

- **Rules**: Regras de roteamento (host, path, backend)
- **Events**: Eventos do Ingress Controller
- **Backend**: Services e portas de destino

### Ver logs do Ingress Controller

```bash
# Logs do NGINX Ingress Controller
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx -f
```

### Editar Ingress em runtime

```bash
kubectl edit ingress myapp-ingress -n webinar5
```

### Testar com curl (forçar Host header)

```bash
MINIKUBE_IP=$(minikube ip)

# Forçar host header
curl -H "Host: myapp.local" http://${MINIKUBE_IP}/
curl -H "Host: myapp.local" http://${MINIKUBE_IP}/api/health
```

### Debug de Ingress

```bash
# Ver configuração NGINX gerada
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf

# Ver upstreams configurados
kubectl exec -n ingress-nginx deploy/ingress-nginx-controller -- cat /etc/nginx/nginx.conf | grep upstream -A 5
```

---

## 12) Diferenças: NodePort vs Ingress

| Característica | NodePort | Ingress |
|----------------|----------|---------|
| **URL** | IP:30000-32767 | dominio.com/path |
| **Roteamento** | Um service = uma porta | Múltiplos services no mesmo IP/porta |
| **Path routing** | ❌ Não | ✅ Sim |
| **Host routing** | ❌ Não | ✅ Sim |
| **SSL/TLS** | ❌ Cada service | ✅ Centralizado |
| **Load balancing** | ✅ Basic | ✅ Avançado |
| **Uso** | Dev/Teste | Produção |

### Quando usar cada um?

**NodePort:**
- ✅ Desenvolvimento local rápido
- ✅ Testes temporários
- ✅ Quando não precisa de roteamento complexo

**Ingress:**
- ✅ Produção
- ✅ Múltiplos serviços no mesmo domínio
- ✅ SSL/TLS
- ✅ Roteamento complexo (path, host, headers)
- ✅ URLs user-friendly

**Arquitetura recomendada:**

```
Internet
    ↓
Ingress Controller (NGINX)
    ↓
Ingress Rules (myapp.local, /api)
    ↓
Services (ClusterIP)
    ↓
Pods
```

---

## 13) Comparação com Cloud Providers

### Minikube (Local)

```yaml
spec:
  ingressClassName: nginx  # NGINX Ingress Controller (addon)
```

### AWS (EKS)

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: alb  # AWS ALB Ingress Controller
```

### GCP (GKE)

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: gce  # GCP Load Balancer
```

### Azure (AKS)

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: azure/application-gateway
```

**Nota:** Em produção (cloud), o Ingress Controller provisiona automaticamente um **Load Balancer externo** (AWS ELB/ALB, GCP LB, Azure LB).

---

## 14) Limpeza

### Deletar recursos específicos

```bash
kubectl delete -f all-in-one.yaml
```

### Deletar namespace (remove tudo)
    
```bash
kubectl delete namespace webinar5
```

### Remover /etc/hosts

```bash
sudo nano /etc/hosts
# Remover linha: 192.168.49.2 myapp.local api.myapp.local
```

### Desabilitar addon Ingress (opcional)

```bash
minikube addons disable ingress
```

### Verificar limpeza

```bash
kubectl get all -n webinar5
kubectl get ingress -n webinar5
```

---

## 15) Resumo e próximos passos

### O que aprendemos

✅ **O que é Ingress** - roteamento HTTP/HTTPS inteligente
✅ **Ingress Controller** - NGINX no Minikube
✅ **Roteamento por Path** - `/` e `/api`
✅ **Roteamento por Host** - `myapp.local` e `api.myapp.local`
✅ **Annotations** - configurações avançadas
✅ **Arquitetura production-ready** - ClusterIP + Ingress

### Benefícios do Ingress

- ✅ URLs amigáveis
- ✅ Roteamento inteligente
- ✅ SSL/TLS centralizado
- ✅ Menor uso de portas
- ✅ Escalável e profissional

### Próximos passos

- **ConfigMaps e Secrets**: Gerenciar configurações
- **Volumes e Persistent Storage**: Dados persistentes
- **StatefulSets**: Aplicações stateful (bancos de dados)
- **Helm**: Gerenciador de pacotes do Kubernetes
- **Monitoring**: Prometheus + Grafana
- **CI/CD**: Integração contínua com Kubernetes

---

## Recursos Adicionais

### Documentação Oficial

- [Kubernetes Ingress](https://kubernetes.io/docs/concepts/services-networking/ingress/)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)
- [Ingress Annotations](https://kubernetes.github.io/ingress-nginx/user-guide/nginx-configuration/annotations/)

### Exemplos de Ingress

- [Path-based routing](https://kubernetes.io/docs/concepts/services-networking/ingress/#simple-fanout)
- [Name-based virtual hosting](https://kubernetes.io/docs/concepts/services-networking/ingress/#name-based-virtual-hosting)
- [TLS/HTTPS](https://kubernetes.io/docs/concepts/services-networking/ingress/#tls)

### Outros Ingress Controllers

- **Traefik**: https://traefik.io/
- **HAProxy**: https://www.haproxy.com/
- **Contour**: https://projectcontour.io/
- **Ambassador**: https://www.getambassador.io/
- **Kong**: https://konghq.com/

---

🎉 **Parabéns!** Você dominou Ingress no Kubernetes!

### O que é um Service?

Um **Service** é uma abstração que define:
- Um **conjunto lógico de pods** (via selector)
- Uma **política de acesso** a esses pods
- Um **IP virtual estável** (ClusterIP) que não muda
- Um **nome DNS** para resolução interna

**Analogia:** Service é como um "balanceador de carga interno" + "registro DNS".

### Tipos de Services

| Tipo | Descrição | Uso |
|------|-----------|-----|
| **ClusterIP** | IP interno do cluster (padrão) | Comunicação entre pods |
| **NodePort** | Expõe em porta alta em cada node | Acesso externo temporário/dev |
| **LoadBalancer** | Provisiona LB externo (cloud) | Produção em cloud |
| **ExternalName** | CNAME para serviço externo | Integração externa |

Nesta live vamos focar em **ClusterIP** e **NodePort**.

---

## 2) Preparando a aplicação backend (versão 3.0)

Vamos usar a web api dentro do diretório `/Apps/MyApp.WebApi`.

### 2.1) Verificar o código

O arquivo `Apps/MyApp.WebApi/Program.cs` já está pronto com os endpoints:

```csharp
// Static products list
var products = new[]
{
    new Product(1, "Laptop", "High-performance laptop", 1299.99m),
    new Product(2, "Smartphone", "Latest model smartphone", 899.99m),
    new Product(3, "Headphones", "Wireless noise-cancelling headphones", 249.99m),
    new Product(4, "Keyboard", "Mechanical gaming keyboard", 129.99m),
    new Product(5, "Mouse", "Ergonomic wireless mouse", 59.99m)
};

// Health check endpoint - retorna status e timestamp
app.MapGet("/health", () => Results.Ok(new { status = "healthy", timestamp = DateTime.UtcNow }))
    .WithName("HealthCheck");

// Products endpoints
app.MapGet("/products", () => Results.Ok(products))
    .WithName("GetProducts");

app.MapGet("/products/{id}", (int id) =>
{
    var product = products.FirstOrDefault(p => p.Id == id);
    return product is not null ? Results.Ok(product) : Results.NotFound();
})
.WithName("GetProductById");

// Instance info endpoint - para visualizar load balancing
app.MapGet("/instance", () =>
{
    var uptime = DateTime.UtcNow - startupTime;
    var instance = new InstanceInfo(
        instanceId,
        hostname,
        startupTime,
        $"{uptime.Hours:D2}:{uptime.Minutes:D2}:{uptime.Seconds:D2}"
    );
    return Results.Ok(instance);
})
.WithName("GetInstance");
```

**Endpoints disponíveis:**
- `/health` - Health check (usado pelos probes do Kubernetes)
- `/products` - Lista todos os produtos
- `/products/{id}` - Busca produto por ID
- `/instance` - Informações da instância (para ver load balancing)

### 2.2) Build e push da imagem v3.0

Agora vamos construir a nova versão 3.0 com o health check completo:

```bash
cd Webinars/Webinar4/Apps/MyApp.WebApi

# Fazer login no Docker Hub (se ainda não fez)
docker login

# Build da imagem v3.0
docker build -t tallesvaliatti/myapp-webapi:3.0 .

# Push para Docker Hub
docker push tallesvaliatti/myapp-webapi:3.0
```

**O que mudou na v3.0:**
- ✅ Health check endpoint retorna timestamp

---

## 3) Namespace dedicado

Vamos criar um namespace para organizar nossos recursos:

### namespace.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webinar4
  labels:
    name: webinar4
    purpose: services-demo
```

Aplicar:

```bash
cd Webinars/Webinar4

kubectl apply -f namespace.yaml
```

Verificar:

```bash
kubectl get namespaces
```

---

## 4) Deployment da API (backend)

Vamos criar um Deployment com 3 réplicas da nossa API:

### deployment.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapi
  namespace: webinar4
  labels:
    app: myapp-webapi
    tier: backend
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: myapp-webapi
  template:
    metadata:
      labels:
        app: myapp-webapi
        tier: backend
    spec:
      containers:
      - name: webapi
        image: <docker-hub-account>/myapp-webapi:3.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5
```

**Nota:** O YAML acima usa o placeholder `<docker-hub-account>`. Substitua pelo seu usuário do Docker Hub antes de aplicar.

Aplicar:

```bash
kubectl apply -f deployment.yaml
```

Verificar os pods:

```bash
kubectl get pods -n webinar4 -o wide

# Aguardar até que todos estejam Running (1/1)
kubectl get pods -n webinar4 -w
```

---

## 5) Service ClusterIP (interno)

Agora vamos criar um **Service ClusterIP** para expor a API internamente no cluster.

### service-clusterip.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-service
  namespace: webinar4
  labels:
    app: myapp-webapi
spec:
  type: ClusterIP  # Tipo padrão (pode omitir)
  selector:
    app: myapp-webapi  # Seleciona pods com este label
  ports:
  - name: http
    protocol: TCP
    port: 80          # Porta do Service
    targetPort: 8080  # Porta do container
```

### Entendendo o Service

**Campos importantes:**

- **selector**: Define quais pods fazem parte deste service (label `app: myapp-webapi`)
- **port**: Porta que o service expõe (80)
- **targetPort**: Porta que o container escuta (8080)
- **type: ClusterIP**: IP interno (acessível apenas dentro do cluster)

Aplicar:

```bash
kubectl apply -f service-clusterip.yaml
```

Verificar:

```bash
kubectl get svc -n webinar4

# Ver detalhes
kubectl describe svc myapp-webapi-service -n webinar4
```

**Saída esperada:**

```
NAME                    TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)   AGE
myapp-webapi-service    ClusterIP   10.96.123.45    <none>        80/TCP    10s
```

**Observações:**
- **CLUSTER-IP**: IP virtual estável (não muda)
- **EXTERNAL-IP**: `<none>` porque é ClusterIP
- **PORT(S)**: `80/TCP` - porta que o service expõe

---

## 6) Testando DNS interno do Kubernetes

O Kubernetes provê **DNS automático** para Services!

### DNS Resolution

Quando você cria um Service chamado `myapp-webapi-service` no namespace `webinar4`, o Kubernetes automaticamente cria entradas DNS:

**Formatos de DNS:**

```
<service-name>                          # Mesmo namespace
<service-name>.<namespace>              # Outro namespace
<service-name>.<namespace>.svc          # Completo
<service-name>.<namespace>.svc.cluster.local  # FQDN completo
```

### 6.1) Testar DNS de dentro de um pod

Vamos criar um pod temporário para testar:

```bash
kubectl run test-pod -n webinar4 --image=busybox --rm -it --restart=Never -- sh
```

**Dentro do pod:**

```sh
# Testar resolução DNS (nome curto - mesmo namespace)
nslookup myapp-webapi-service

# Testar resolução DNS (completo)
nslookup myapp-webapi-service.webinar4.svc.cluster.local

# Testar endpoint /instance várias vezes
wget -qO- http://myapp-webapi-service/instance
wget -qO- http://myapp-webapi-service/instance
wget -qO- http://myapp-webapi-service/instance
```

**O que observar:**

1. O DNS resolve para o **ClusterIP** do service
2. As requisições HTTP funcionam
3. O endpoint `/instance` retorna **pods diferentes** a cada chamada (load balancing)

Para sair do pod:

```sh
exit
```

### 6.2) Testar com curl (pod com curl)

```bash
kubectl run curl-pod -n webinar4 --image=curlimages/curl --rm -it --restart=Never -- sh
```

**Dentro do pod:**

```sh
# Testar múltiplas requisições
curl -s http://myapp-webapi-service/instance
```

Você verá diferentes `InstanceId` - isso prova que o Service está fazendo **load balancing** entre os 3 pods! 🎉

Para sair:

```sh
exit
```

---

## 7) Service NodePort (acesso externo)

O **ClusterIP** só é acessível de dentro do cluster. Para acessar de fora (do seu laptop), precisamos de um **NodePort**.

### service-nodeport.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-nodeport
  namespace: webinar4
  labels:
    app: myapp-webapi
spec:
  type: NodePort
  selector:
    app: myapp-webapi
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080  # Porta no node (range: 30000-32767)
```

**Diferença do ClusterIP:**

- **type: NodePort**: Abre porta em cada node do cluster
- **nodePort**: Porta específica (30000-32767) - opcional, K8s pode gerar automaticamente

Aplicar:

```bash
kubectl apply -f service-nodeport.yaml
```

Verificar:

```bash
kubectl get svc -n webinar4

# Ver detalhes
kubectl describe svc myapp-webapi-nodeport -n webinar4
```

**Saída esperada:**

```
NAME                      TYPE        CLUSTER-IP      EXTERNAL-IP   PORT(S)        AGE
myapp-webapi-nodeport     NodePort    10.96.234.56    <none>        80:30080/TCP   10s
myapp-webapi-service      ClusterIP   10.96.123.45    <none>        80/TCP         5m
```

---

## 8) Acessando via NodePort

### 8.1) Obter URL do Minikube

O Minikube tem um comando para obter a URL do service:

```bash
minikube service myapp-webapi-nodeport -n webinar4 --url
```

**Saída esperada:**

```
http://192.168.49.2:30080
```

### 8.2) Testar no navegador

Abrir no navegador:

```
http://192.168.49.2:30080
http://192.168.49.2:30080/health
http://192.168.49.2:30080/instance
```

**📝 Nota importante para macOS:**

No macOS, o Minikube usa Docker Desktop e não expõe diretamente o IP do node (192.168.49.2). Em vez disso, o comando `minikube service --url` cria automaticamente um **túnel SSH** e retorna um endereço localhost com porta dinâmica.

**Exemplo no macOS:**

```bash
minikube service myapp-webapi-nodeport -n webinar4 --url
```

**Saída no macOS:**

```
http://127.0.0.1:60000
```

**Testando com curl:**

```bash
curl http://127.0.0.1:60000/instance
```

**Resposta:**

```json
{
  "instanceId": "90830915",
  "hostname": "myapp-webapi-b5f556567-xrwgq",
  "startupTime": "2026-01-14T14:47:44.3395329Z",
  "uptime": "00:14:10"
}
```

**O que está acontecendo?**

1. **Túnel automático**: O Minikube detecta que você está no macOS e cria um túnel SSH do localhost para o NodePort do cluster
2. **Porta dinâmica**: A porta (ex: 60000) é alocada dinamicamente e pode mudar a cada execução
3. **Localhost**: Você acessa via `127.0.0.1` em vez do IP do node
4. **Load balancing funciona**: Mesmo através do túnel, o Service distribui as requisições entre os pods

**Vantagem**: Funciona de forma transparente sem precisar configurar nada adicional!
---

### 8.3) Testar no terminal (script)

Vamos criar um script para testar o load balancing:

### test-load-balancing.sh

```bash
#!/bin/bash

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if URL is provided as parameter
if [ -z "$1" ]; then
  echo -e "${RED}Error: URL not provided!${NC}"
  echo -e "${YELLOW}Usage: $0 <url> [port]${NC}"
  echo -e "${YELLOW}Example: $0 http://127.0.0.1:60000${NC}"
  echo -e "${YELLOW}Example: $0 http://127.0.0.1:60000/instance${NC}"
  echo -e "${YELLOW}Example: $0 http://127.0.0.1 60000${NC}"
  echo -e "${YELLOW}Example: $0 http://192.168.49.2:30080${NC}"
  echo ""
  echo -e "${BLUE}Note: You can include or omit the /instance endpoint${NC}"
  echo ""
  echo -e "${BLUE}Tip: Get the URL with:${NC}"
  echo -e "  minikube service myapp-webapi-nodeport -n webinar4 --url"
  exit 1
fi

# Build service URL
if [ -z "$2" ]; then
  # URL includes port (e.g., http://192.168.49.2:30080)
  SERVICE_URL="$1"
else
  # URL and port provided separately (e.g., http://127.0.0.1 60000)
  SERVICE_URL="$1:$2"
fi

# Remove trailing slash if present
SERVICE_URL="${SERVICE_URL%/}"

# Remove /instance endpoint if user provided it (we'll add it in the loop)
SERVICE_URL="${SERVICE_URL%/instance}"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Testing Load Balancing${NC}"
echo -e "${BLUE}========================================${NC}"
echo -e "${YELLOW}Service URL: ${SERVICE_URL}${NC}\n"

# Test /instance endpoint multiple times
echo -e "${GREEN}Testing /instance endpoint (10 requests):${NC}\n"

for i in {1..10}; do
  echo -e "${YELLOW}Request #${i}:${NC}"
  RESPONSE=$(curl -s "${SERVICE_URL}/instance")
  
  if [ -z "$RESPONSE" ]; then
    echo -e "${RED}Error: No response from server${NC}"
  else
    echo "$RESPONSE" | jq '.'
  fi
  
  echo ""
  sleep 0.5
done

echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}Summary:${NC}"
echo -e "You should see different InstanceId and Hostname values,"
echo -e "proving that the Service is load balancing across pods!"
echo -e "${BLUE}========================================${NC}"
```

**Como usar:**

Primeiro, obtenha a URL do service:

```bash
minikube service myapp-webapi-nodeport -n webinar4 --url
```

**📝 Nota:** O script aceita a URL **com ou sem** o endpoint `/instance`. Ele automaticamente normaliza a URL.

**Opção 1: URL completa (Linux/Windows):**

```bash
chmod +x test-load-balancing.sh
./test-load-balancing.sh http://192.168.49.2:30080
```

**Opção 2: URL e porta separadas (macOS):**

```bash
chmod +x test-load-balancing.sh
./test-load-balancing.sh http://127.0.0.1 60000
```

**Opção 3: URL com endpoint /instance incluído:**

```bash
./test-load-balancing.sh http://127.0.0.1:60125/instance
```

**Opção 4: Capturar URL automaticamente e passar para o script:**

```bash
URL=$(minikube service myapp-webapi-nodeport -n webinar4 --url)
./test-load-balancing.sh $URL
```

**O que você deve observar:**

- **InstanceId** diferente a cada requisição
- **Hostname** alternando entre os 3 pods
- Isso prova que o Service está distribuindo as requisições!

---

## 9) Arquitetura Multi-Serviço (Web → API)

Agora vamos criar uma arquitetura mais realista: um **frontend web** que chama a **API backend**.

### 9.1) Sobre o projeto MyApp.WebApp

Vamos usar o projeto **MyApp.WebApp** que já está criado. É uma aplicação **ASP.NET Core MVC** que:
- Renderiza uma interface web com Bootstrap
- Faz chamadas HTTP para a API backend
- Exibe informações de instância da API (load balancing)
- Lista produtos retornados pela API

**Estrutura do projeto:**
- `Controllers/HomeController.cs` - Controller que chama a API
- `Views/Home/Index.cshtml` - View com interface visual
- `Models/` - ViewModels para dados da API
- `appsettings.json` - Configuração da URL da API

### 9.2) Configurar URL da API

O projeto usa `appsettings.json` para configurar a URL da API backend.

### Apps/MyApp.WebApp/appsettings.json

```json
{
  "Logging": {
    "LogLevel": {
      "Default": "Information",
      "Microsoft.AspNetCore": "Warning"
    }
  },
  "AllowedHosts": "*",
  "ApiSettings": {
    "WebApiUrl": "http://myapp-webapi-service.webinar4.svc.cluster.local"
  }
}
```

**Nota:** A URL usa o **DNS interno do Kubernetes**:
- `myapp-webapi-service` - nome do Service
- `webinar4` - namespace
- `svc.cluster.local` - sufixo DNS do Kubernetes

### 9.3) Criar Dockerfile do MyApp.WebApp

Vamos criar um Dockerfile multi-stage para build otimizado:

### Apps/MyApp.WebApp/Dockerfile

```dockerfile
# Build stage
FROM mcr.microsoft.com/dotnet/sdk:10.0 AS build
WORKDIR /src

# Copy csproj and restore dependencies
COPY MyApp.WebApp.csproj .
RUN dotnet restore

# Copy everything else and build
COPY . .
RUN dotnet publish -c Release -o /app/publish

# Runtime stage
FROM mcr.microsoft.com/dotnet/aspnet:10.0 AS runtime
WORKDIR /app
COPY --from=build /app/publish .

# Set environment variables
ENV ASPNETCORE_URLS=http://+:8080
ENV ASPNETCORE_ENVIRONMENT=Production

EXPOSE 8080

ENTRYPOINT ["dotnet", "MyApp.WebApp.dll"]
```

**Explicação do Dockerfile:**

- **Multi-stage build**: Build em uma imagem SDK, runtime em imagem menor (aspnet)
- **Stage 1 (build)**: Compila a aplicação .NET
- **Stage 2 (runtime)**: Copia apenas os binários compilados
- **Porta 8080**: Mesma porta usada pela API
- **Resultado**: Imagem otimizada (~200MB vs ~700MB do SDK)

### 9.4) Build e push da imagem do frontend

Navegar até o diretório do projeto e fazer build:

```bash
cd Webinars/Webinar4/Apps/MyApp.WebApp

# Build da imagem
docker build -t <docker-hub-account>/myapp-webapp:1.0 .

# Login no Docker Hub (se ainda não estiver logado)
docker login

# Push para Docker Hub
docker push <docker-hub-account>/myapp-webapp:1.0
```

**Importante:** Troque `<docker-hub-account>` pelo seu nome de usuário do Docker Hub!

**Exemplo real:**

```bash
docker build -t tallesvaliatti/myapp-webapp:1.0 .
docker push tallesvaliatti/myapp-webapp:1.0
```

**Verificar imagem criada:**

```bash
docker images | grep myapp-webapp
```

**Testar localmente (opcional):**

```bash
# Primeiro inicie a API localmente ou use uma URL pública
docker run -p 8080:8080 -e ApiSettings__WebApiUrl=http://localhost:5000 $DOCKER_USER/myapp-webapp:1.0

# Abrir no navegador: http://localhost:8080
```

### 9.5) Deployment do frontend

Vamos criar o Deployment para o MyApp.WebApp:

### deployment-webapp.yaml

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapp
  namespace: webinar4
  labels:
    app: myapp-webapp
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp-webapp
  template:
    metadata:
      labels:
        app: myapp-webapp
        tier: frontend
    spec:
      containers:
      - name: webapp
        image: <docker-hub-account>/myapp-webapp:1.0
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

```

**Observações importantes:**

- **Nome**: `myapp-webapp`
- **Porta**: 8080 (aplicação ASP.NET Core)

Aplicar:

```bash
kubectl apply -f deployment-webapp.yaml
```

Verificar:

```bash
kubectl get pods -n webinar4 -l app=myapp-webapp
```

### 9.6) Service NodePort para o frontend

### service-web-nodeport.yaml

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapp-service
  namespace: webinar4
  labels:
    app: myapp-webapp
spec:
  type: NodePort
  selector:
    app: myapp-webapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30090
```

**Observações:**

- **selector**: `app: myapp-webapp` (mesmo label do Deployment)
- **port**: 80 (porta do Service internamente)
- **targetPort**: 8080 (porta do container)
- **nodePort**: 30090 (porta externa no node)

Aplicar:

```bash
kubectl apply -f service-web-nodeport.yaml
```

Verificar:

```bash
kubectl get svc -n webinar4 myapp-webapp-service
```

### 9.7) Testar a aplicação completa

Obter URL do frontend:

```bash
minikube service myapp-webapp-service -n webinar4 --url
```

Isso retorna algo como: `http://192.168.49.2:30090`

Abrir no navegador e você verá:
- **Interface web** do MyApp.WebApp
- **Botão "Atualizar"** para chamar a API
- **Informações da instância** da API (hostname, instance ID, uptime)
- **Lista de produtos** retornados pela API
- **Cada refresh** pode mostrar um pod diferente (load balancing)

🎉 **Arquitetura multi-serviço funcionando!**

**Fluxo completo:**

1. Navegador → NodePort (30090)
2. NodePort → Service `myapp-webapp-service`
3. Service → Pods do MyApp.WebApp
4. MyApp.WebApp → Service `myapp-webapi-service` (DNS interno)
5. Service → Pods do MyApp.WebApi
6. Response ← volta todo o caminho

---

## 10) All-in-One YAML

Para facilitar, vamos criar um único arquivo com todos os recursos:

### all-in-one.yaml

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: webinar4
  labels:
    name: webinar4
    purpose: services-demo

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapi
  namespace: webinar4
  labels:
    app: myapp-webapi
    tier: backend
spec:
  replicas: 3
  strategy:
    type: Recreate
  selector:
    matchLabels:
      app: myapp-webapi
  template:
    metadata:
      labels:
        app: myapp-webapi
        tier: backend
    spec:
      containers:
      - name: webapi
        image: tallesvaliatti/myapp-webapi:3.0
        ports:
        - containerPort: 8080
          name: http
        env:
        - name: ASPNETCORE_URLS
          value: "http://+:8080"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        livenessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 10
          periodSeconds: 10
        readinessProbe:
          httpGet:
            path: /health
            port: 8080
          initialDelaySeconds: 5
          periodSeconds: 5

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-service
  namespace: webinar4
  labels:
    app: myapp-webapi
spec:
  type: ClusterIP
  selector:
    app: myapp-webapi
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi-nodeport
  namespace: webinar4
  labels:
    app: myapp-webapi
spec:
  type: NodePort
  selector:
    app: myapp-webapi
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30080

---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: myapp-webapp
  namespace: webinar4
  labels:
    app: myapp-webapp
    tier: frontend
spec:
  replicas: 2
  selector:
    matchLabels:
      app: myapp-webapp
  template:
    metadata:
      labels:
        app: myapp-webapp
        tier: frontend
    spec:
      containers:
      - name: webapp
        image: <docker-hub-account>/myapp-webapp:1.0
        ports:
        - containerPort: 8080
          name: http
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "50m"

---
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapp-service
  namespace: webinar4
  labels:
    app: myapp-webapp
spec:
  type: NodePort
  selector:
    app: myapp-webapp
  ports:
  - name: http
    protocol: TCP
    port: 80
    targetPort: 8080
    nodePort: 30090
```

**Deploy completo:**

```bash
# ANTES: trocar '<docker-hub-account>' pelo seu usuário do Docker Hub

kubectl apply -f all-in-one.yaml
```

**Verificar tudo:**

```bash
kubectl get all -n webinar4
```

---

## 11) Comandos úteis de Services

### Listar Services

```bash
# Todos os namespaces
kubectl get svc --all-namespaces

# Namespace específico
kubectl get svc -n webinar4

# Com mais detalhes
kubectl get svc -n webinar4 -o wide
```

### Descrever Service

```bash
kubectl describe svc myapp-webapi-service -n webinar4
```

**O que observar:**

- **Endpoints**: IPs dos pods que fazem parte do service
- **Selector**: Labels usados para selecionar pods
- **Session Affinity**: None (default) - round-robin load balancing

### Ver Endpoints

```bash
kubectl get endpoints -n webinar4

# Detalhes
kubectl describe endpoints myapp-webapi-service -n webinar4
```

Os **Endpoints** são os IPs reais dos pods. O Service encaminha tráfego para esses IPs.

### Port-forward (alternativa para testar)

Se não quiser usar NodePort, pode fazer port-forward:

```bash
# Forward local port 8080 para o service
kubectl port-forward -n webinar4 svc/myapp-webapi-service 8080:80

# Em outro terminal, testar
curl http://localhost:8080/instance
```

### Logs dos pods por label

```bash
# Logs de todos os pods da API
kubectl logs -n webinar4 -l app=myapp-webapi --tail=20

# Seguir logs em tempo real
kubectl logs -n webinar4 -l app=myapp-webapi -f
```

## 12) Diferenças entre ClusterIP, NodePort e LoadBalancer

| Característica | ClusterIP | NodePort | LoadBalancer |
|----------------|-----------|----------|--------------|
| **Acesso** | Interno apenas | Node IP + Porta alta | IP público externo |
| **IP estável** | Sim (ClusterIP) | Não (IP do node pode mudar) | Sim (LB IP) |
| **Porta** | Qualquer | 30000-32767 | Qualquer (80, 443) |
| **Uso** | Inter-pod communication | Dev/Teste | Produção (cloud) |
| **Cloud** | Não depende | Não depende | Requer cloud provider |

### Quando usar cada tipo?

- **ClusterIP**: Comunicação interna entre pods (default)
- **NodePort**: Acesso temporário externo (dev/teste)
- **LoadBalancer**: Produção em cloud (AWS, GCP, Azure)

No Minikube:
- Use **ClusterIP** para comunicação interna
- Use **NodePort** ou `minikube service` para acesso externo

Em produção (cloud):
- Use **ClusterIP** para serviços internos
- Use **LoadBalancer** para serviços externos

---

## 13) Limpeza

### Deletar recursos específicos

```bash
kubectl delete -f all-in-one.yaml
```

### Deletar namespace (remove tudo)
    
```bash
kubectl delete namespace webinar4
```

### Verificar limpeza

```bash
kubectl get all -n webinar4
```