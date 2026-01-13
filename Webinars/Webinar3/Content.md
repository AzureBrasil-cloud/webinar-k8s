# Live 3 — Deployments: scale, rollout e rollback

Objetivo da live: dominar **Deployments** no Kubernetes, aprendendo a **escalar réplicas**, fazer **rollout de novas versões**, acompanhar o **status das atualizações** e fazer **rollback** quando necessário.

**Entregável:** pipeline mental de "publicar versão com segurança" usando estratégias de deployment.

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

---

## O que vamos aprender

1. **Escalar réplicas** - aumentar/diminuir pods para lidar com carga
2. **Estratégias de rollout** - RollingUpdate vs Recreate
3. **Atualizar imagem** - deploy de nova versão com zero downtime
4. **Acompanhar rollout** - monitorar status da atualização
5. **Rollback** - reverter para versão anterior em caso de problema
6. **Health checks** - readiness e liveness probes
7. **Load balancing** - testar distribuição de requisições

---

## 1) Novo endpoint para visualizar instâncias

Para esta live, adicionamos um novo endpoint `/instance` na aplicação que retorna:
- **instanceId**: identificador único gerado no startup
- **hostname**: nome do pod
- **startupTime**: quando o pod iniciou
- **uptime**: há quanto tempo está rodando

Isso nos permite **visualizar o load balancing** e ver diferentes pods respondendo às requisições.

### Implementação no Program.cs

O código já está implementado em `Apps/MyApp.WebApi/Program.cs`:

```csharp
// Instance information (generated at startup)
var instanceId = Guid.NewGuid().ToString("N")[..8]; // First 8 chars of GUID
var hostname = Environment.MachineName;
var startupTime = DateTime.UtcNow;

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

record InstanceInfo(string InstanceId, string Hostname, DateTime StartupTime, string Uptime);
```

**Este endpoint é a novidade da versão 2.0!** 🚀

### Testar localmente (opcional)

Se quiser testar a aplicação antes de fazer o build:

```bash
cd Webinars/Webinar3/Apps/MyApp.WebApi
dotnet run
```

Em outro terminal:

```bash
# Testar o novo endpoint
curl http://localhost:5023/instance

---

## 2) Build e push da nova versão (2.0)

Agora vamos criar a imagem Docker **versão 2.0** que inclui o novo endpoint `/instance`.

### 2.1) Build da nova imagem

```bash
cd Webinars/Webinar3/Apps/MyApp.WebApi

docker build -t <seu-docker-hub-account>/myapp-webapi:2.0 .
```

**Substitua** `<seu-docker-hub-account>` pelo seu usuário do Docker Hub.

**Importante:** Esta versão 2.0 inclui:
- ✅ Endpoint `/products` (já existente)
- ✅ Endpoint `/products/{id}` (já existente)
- ✅ **Novo:** Endpoint `/instance` (para visualizar load balancing)

### 2.2) Push para Docker Hub

```bash
docker push <seu-docker-hub-account>/myapp-webapi:2.0
```

### 2.3) Verificar imagem

```bash
docker images | grep myapp-webapi
```

Esperado: ver as versões `1.0` e `2.0`.

---

## 3) Criar namespace myapp

Vamos começar do zero! Primeiro, criar o namespace onde nossa aplicação vai rodar:

### 3.1) Verificar se já existe

```bash
kubectl get namespaces
```

Se o namespace `myapp` já existir de lives anteriores, vamos deletar para começar limpo:

```bash
# Deletar namespace (isso remove TODOS os recursos dentro dele)
kubectl delete namespace myapp
```

### 3.2) Criar novo namespace

```bash
cd Webinars/Webinar3

kubectl apply -f namespace.yaml
```

### 3.3) Verificar criação

```bash
kubectl get namespace myapp
```

Esperado:
```
NAME    STATUS   AGE
myapp   Active   5s
```

### 3.4) Ver detalhes do namespace

```bash
kubectl describe namespace myapp
```

Você verá as labels que definimos:
- `name: myapp`
- `environment: production`

### 3.5) Confirmar que está vazio

```bash
kubectl get all -n myapp
```

Esperado: `No resources found in myapp namespace.`

Perfeito! Agora temos um namespace limpo para trabalhar. 🎯

---

## 4) Criar Deployment com 3 réplicas

### 4.1) Entender o deployment.yaml

Navegue até `Webinars/Webinar3/deployment.yaml` e observe as configurações importantes:

```yaml
spec:
  replicas: 3  # Número inicial de pods
  
  strategy:
    type: RollingUpdate  # Estratégia de atualização
    rollingUpdate:
      maxSurge: 1         # Pode criar 1 pod extra durante update
      maxUnavailable: 0   # Nenhum pod pode ficar indisponível
```

**RollingUpdate** garante:
- ✅ Zero downtime durante atualizações
- ✅ Rollout gradual (pod por pod)
- ✅ Possibilidade de rollback

**Health checks** adicionados:

```yaml
livenessProbe:   # Verifica se o pod está vivo
  httpGet:
    path: /products
    port: 8080
  initialDelaySeconds: 10
  periodSeconds: 10

readinessProbe:  # Verifica se o pod está pronto para receber tráfego
  httpGet:
    path: /products
    port: 8080
  initialDelaySeconds: 5
  periodSeconds: 5
```

### 4.2) Aplicar o deployment

**IMPORTANTE:** Antes de aplicar, edite o arquivo `deployment.yaml` e substitua `<docker-hub-account>` pelo seu usuário do Docker Hub!

```bash
cd Webinars/Webinar3

# Aplicar deployment
kubectl apply -f deployment.yaml
```

### 4.3) Verificar criação dos pods

```bash
kubectl get pods -n myapp -w
```

O `-w` (watch) mostra as mudanças em tempo real.

Esperado: ver 3 pods sendo criados:
```
NAME                             READY   STATUS              RESTARTS   AGE
myapp-webapi-xxxxxxxxxx-xxxxx    0/1     ContainerCreating   0          2s
myapp-webapi-xxxxxxxxxx-xxxxx    0/1     ContainerCreating   0          2s
myapp-webapi-xxxxxxxxxx-xxxxx    0/1     ContainerCreating   0          2s
...
myapp-webapi-xxxxxxxxxx-xxxxx    1/1     Running             0          15s
myapp-webapi-xxxxxxxxxx-xxxxx    1/1     Running             0          15s
myapp-webapi-xxxxxxxxxx-xxxxx    1/1     Running             0          15s
```

**Pressione Ctrl+C** para sair do watch.

### 4.4) Verificar deployment

```bash
kubectl get deployment -n myapp
```

Esperado:
```
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
myapp-webapi   3/3     3            3           1m
```

- **READY**: 3/3 = 3 pods prontos de 3 desejados
- **UP-TO-DATE**: 3 pods na versão mais recente
- **AVAILABLE**: 3 pods disponíveis para receber tráfego

---

## 5) Criar Service para expor a aplicação

### 5.1) Entender o service.yaml

Navegue até `Webinars/Webinar3/service.yaml` e observe:

```yaml
apiVersion: v1
kind: Service
metadata:
  name: myapp-webapi
  namespace: myapp
spec:
  selector:
    app: myapp-webapi  # Seleciona pods com este label
  ports:
    - protocol: TCP
      port: 8080        # Porta do Service
      targetPort: 8080  # Porta do container
  type: ClusterIP       # Acesso interno ao cluster
```

O Service atua como um **load balancer interno**, distribuindo requisições entre os 3 pods.

### 5.2) Aplicar o Service

```bash
kubectl apply -f service.yaml
```

### 5.3) Verificar Service

```bash
kubectl get service -n myapp
```

Esperado:
```
NAME           TYPE        CLUSTER-IP       EXTERNAL-IP   PORT(S)    AGE
myapp-webapi   ClusterIP   10.96.xxx.xxx    <none>        8080/TCP   5s
```

### 5.4) Ver detalhes

```bash
kubectl describe service myapp-webapi -n myapp
```

Observe a seção **Endpoints** - deve listar os IPs dos 3 pods!

---

## 6) Testar load balancing entre réplicas

### 6.1) Port-forward para o Service

```bash
kubectl port-forward service/myapp-webapi 8080:8080 -n myapp
```

Mantenha esse terminal aberto.

### 6.2) Testar o endpoint /instance

Em **outro terminal**, faça múltiplas requisições:

```bash
# Fazer 10 requisições e ver diferentes instanceId
for i in {1..10}; do
  echo "Requisição $i:"
  curl -s http://localhost:8080/instance | jq .
  echo "---"
  sleep 0.5
done
```

**Se não tiver `jq` instalado**, use sem formatação:

```bash
for i in {1..10}; do
  echo "Requisição $i:"
  curl http://localhost:8080/instance
  echo ""
  echo "---"
  sleep 0.5
done
```

**Resultado esperado**: você verá diferentes valores de `instanceId` e `hostname`, provando que o Service está distribuindo as requisições entre os 3 pods!

Exemplo de saída:

```json
Requisição 1:
{
  "instanceId": "a3f8c2d1",
  "hostname": "myapp-webapi-5d7f8b9c-x7h2k",
  "startupTime": "2026-01-13T10:30:15Z",
  "uptime": "00:05:23"
}
---
Requisição 2:
{
  "instanceId": "b9e4f7a2",
  "hostname": "myapp-webapi-5d7f8b9c-m4p9j",
  "startupTime": "2026-01-13T10:30:17Z",
  "uptime": "00:05:21"
}
---
Requisição 3:
{
  "instanceId": "c1d5e8b3",
  "hostname": "myapp-webapi-5d7f8b9c-n8k5l",
  "startupTime": "2026-01-13T10:30:16Z",
  "uptime": "00:05:22"
}
```

✅ **Isso demonstra o load balancing do Service!**

---

## 7) Escalar réplicas

### 7.1) Escalar para 5 réplicas (imperativo)

```bash
kubectl scale deployment myapp-webapi --replicas=5 -n myapp
```

### 7.2) Acompanhar escalamento

```bash
kubectl get pods -n myapp -w
```

Você verá 2 novos pods sendo criados.

**Pressione Ctrl+C** para sair.

### 7.3) Verificar deployment

```bash
kubectl get deployment -n myapp
```

Esperado: `READY: 5/5`

### 7.4) Testar novamente o load balancing

Mantenha o `port-forward` aberto e execute novamente:

```bash
for i in {1..15}; do 
  echo "Requisição $i: $(curl -s http://localhost:8080/instance | jq -r '.instanceId + " | " + .hostname')"
done
```

Agora você verá **5 instanceId diferentes** sendo distribuídos!

### 7.5) Escalar para baixo

```bash
kubectl scale deployment myapp-webapi --replicas=2 -n myapp
```

Verificar:

```bash
kubectl get pods -n myapp
```

Você verá que 3 pods foram **terminados** e apenas 2 permanecem.

### 7.6) Voltar para 3 réplicas (declarativo)

A forma **recomendada** é editar o YAML e aplicar:

```bash
# Edite deployment.yaml e mude replicas: 3
kubectl apply -f deployment.yaml
```

Ou use:

```bash
kubectl scale deployment myapp-webapi --replicas=3 -n myapp
```

---

## 8) Rollout de nova versão (2.0 → 2.1)

Agora vamos simular uma atualização da aplicação, mudando a versão de `2.0` para `2.1`.

### 8.1) Criar versão 2.1 (simulação)

Para fins didáticos, vamos apenas re-taggear a imagem:

```bash
docker tag <seu-docker-hub-account>/myapp-webapi:2.0 <seu-docker-hub-account>/myapp-webapi:2.1
docker push <seu-docker-hub-account>/myapp-webapi:2.1
```

### 8.2) Atualizar imagem no deployment

**Opção 1 - Imperativo (rápido):**

```bash
kubectl set image deployment/myapp-webapi webapi=<seu-docker-hub-account>/myapp-webapi:2.1 -n myapp
```

**Opção 2 - Declarativo (recomendado):**

Edite `deployment.yaml`, mude a imagem para `2.1` e a label `version: "2.1"`, depois:

```bash
kubectl apply -f deployment.yaml
```

### 8.3) Acompanhar o rollout em tempo real

**Terminal 1** - Ver status do rollout:

```bash
kubectl rollout status deployment/myapp-webapi -n myapp
```

Você verá:

```
Waiting for deployment "myapp-webapi" rollout to finish: 1 out of 3 new replicas have been updated...
Waiting for deployment "myapp-webapi" rollout to finish: 2 out of 3 new replicas have been updated...
Waiting for deployment "myapp-webapi" rollout to finish: 1 old replicas are pending termination...
deployment "myapp-webapi" successfully rolled out
```

**Terminal 2** - Ver pods mudando:

```bash
kubectl get pods -n myapp -w
```

Você verá o **RollingUpdate** em ação:
1. Um novo pod é criado (v2.1)
2. Aguarda ficar `Ready`
3. Um pod antigo é terminado (v2.0)
4. Repete até todos serem atualizados

**Zero downtime!** ✅

### 8.4) Verificar histórico de revisões

```bash
kubectl rollout history deployment/myapp-webapi -n myapp
```

Esperado:

```
REVISION  CHANGE-CAUSE
1         <none>
2         <none>
```

Para adicionar anotações úteis no futuro:

```bash
kubectl annotate deployment/myapp-webapi kubernetes.io/change-cause="Update to version 2.1" -n myapp
```

---

## 9) Rollback para versão anterior

Simulando um problema na versão 2.1, vamos fazer rollback.

### 9.1) Fazer rollback

```bash
kubectl rollout undo deployment/myapp-webapi -n myapp
```

### 9.2) Acompanhar rollback

```bash
kubectl rollout status deployment/myapp-webapi -n myapp
```

### 9.3) Verificar pods

```bash
kubectl get pods -n myapp
```

Os pods foram recriados com a imagem anterior (v2.0).

### 9.4) Rollback para revisão específica

Ver histórico:

```bash
kubectl rollout history deployment/myapp-webapi -n myapp
```

Rollback para revisão específica:

```bash
kubectl rollout undo deployment/myapp-webapi --to-revision=1 -n myapp
```

---

## 10) Estratégias de deployment

### 10.1) RollingUpdate (padrão)

**Características:**
- ✅ Zero downtime
- ✅ Rollout gradual
- ✅ Configurável (maxSurge, maxUnavailable)
- ⚠️ Pode ter versões antigas e novas rodando simultaneamente

**Quando usar:** 
- Aplicações stateless
- APIs REST
- Microserviços

### 10.2) Recreate (alternativa)

**Características:**
- ⚠️ Downtime durante atualização
- ✅ Garante que apenas uma versão rode por vez
- ✅ Simples e rápido

**Quando usar:**
- Aplicações que não suportam múltiplas versões
- Migrações de banco que quebram compatibilidade
- Desenvolvimento/testes

Para usar Recreate, edite `deployment.yaml`:

```yaml
spec:
  strategy:
    type: Recreate
```

---

## 11) Health checks em ação

### 11.1) Verificar health checks

Vamos criar um cenário onde um pod fica "não pronto".

**Opção 1 - Mudar readinessProbe para path inexistente:**

Edite `deployment.yaml`:

```yaml
readinessProbe:
  httpGet:
    path: /health  # path que não existe
    port: 8080
```

Aplique:

```bash
kubectl apply -f deployment.yaml
```

Observe os pods:

```bash
kubectl get pods -n myapp
```

Você verá pods com `READY: 0/1` porque o readinessProbe está fallhando.

O Service **não roteia tráfego** para pods não prontos! ✅

### 11.2) Verificar eventos

```bash
kubectl describe pod <nome-do-pod> -n myapp
```

Na seção `Events`, você verá:

```
Warning  Unhealthy  Readiness probe failed: HTTP probe failed with statuscode: 404
```

### 11.3) Corrigir

Volte o path para `/products` e aplique novamente.

---

## 12) Boas práticas de Deployment

### ✅ Sempre use RollingUpdate para aplicações stateless

```yaml
strategy:
  type: RollingUpdate
  rollingUpdate:
    maxSurge: 1
    maxUnavailable: 0
```

### ✅ Configure health checks

```yaml
readinessProbe:  # Quando o pod está pronto para tráfego
  httpGet:
    path: /health
    port: 8080

livenessProbe:   # Quando o pod está vivo
  httpGet:
    path: /health
    port: 8080
```

### ✅ Defina resource limits

```yaml
resources:
  requests:
    memory: "128Mi"
    cpu: "100m"
  limits:
    memory: "256Mi"
    cpu: "200m"
```

### ✅ Mantenha histórico de revisões

```yaml
spec:
  revisionHistoryLimit: 10  # Últimas 10 versões
```

### ✅ Use labels consistentes

```yaml
labels:
  app: myapp-webapi
  version: "2.0"
  environment: production
```

### ✅ Anote mudanças importantes

```bash
kubectl annotate deployment/myapp-webapi \
  kubernetes.io/change-cause="Deploy v2.0 with new feature" \
  -n myapp
```

---

## 13) Comandos úteis para Deployments

### Ver detalhes do deployment

```bash
kubectl describe deployment myapp-webapi -n myapp
```

### Ver logs de todos os pods

```bash
kubectl logs -l app=myapp-webapi -n myapp --tail=20
```

### Ver logs de um pod específico

```bash
kubectl logs <nome-do-pod> -n myapp -f
```

### Pausar rollout

```bash
kubectl rollout pause deployment/myapp-webapi -n myapp
```

### Resumir rollout

```bash
kubectl rollout resume deployment/myapp-webapi -n myapp
```

### Reiniciar deployment (força recriação dos pods)

```bash
kubectl rollout restart deployment/myapp-webapi -n myapp
```

### Deletar deployment

```bash
kubectl delete deployment myapp-webapi -n myapp
```

---

## 14) Exercícios práticos

### Exercício 1: Zero downtime deployment

1. Garanta que tem 3 réplicas rodando
2. Inicie `port-forward` e deixe rodando
3. Em outro terminal, rode um loop de requisições contínuas:

```bash
while true; do 
  curl -s http://localhost:8080/instance | jq -r '.instanceId'
  sleep 0.3
done
```

4. Em outro terminal, faça um rollout:

```bash
kubectl set image deployment/myapp-webapi webapi=<seu-account>/myapp-webapi:2.1 -n myapp
```

5. Observe que **nenhuma requisição falha** durante o rollout! ✅

### Exercício 2: Rollback rápido

1. Simule um deploy com problema (use uma tag de imagem que não existe):

```bash
kubectl set image deployment/myapp-webapi webapi=<seu-account>/myapp-webapi:broken -n myapp
```

2. Observe os pods falhando:

```bash
kubectl get pods -n myapp -w
```

3. Faça rollback imediato:

```bash
kubectl rollout undo deployment/myapp-webapi -n myapp
```

4. Verifique que voltou ao normal.

### Exercício 3: Escalonamento automático (preparação)

Embora o **HPA (Horizontal Pod Autoscaler)** seja tema de outra live, você pode experimentar:

```bash
kubectl autoscale deployment myapp-webapi --min=2 --max=10 --cpu-percent=70 -n myapp
```

Verificar:

```bash
kubectl get hpa -n myapp
```

---

## 15) Troubleshooting comum

### Problema: Pods não ficam Ready

**Diagnóstico:**

```bash
kubectl describe pod <nome-do-pod> -n myapp
kubectl logs <nome-do-pod> -n myapp
```

**Causas comuns:**
- Readiness probe falhando
- Aplicação demora muito para iniciar
- Erro na aplicação
- Recursos insuficientes

**Soluções:**
- Aumentar `initialDelaySeconds` nos probes
- Verificar logs da aplicação
- Ajustar resource requests

### Problema: Rollout travado

**Diagnóstico:**

```bash
kubectl rollout status deployment/myapp-webapi -n myapp
kubectl describe deployment myapp-webapi -n myapp
```

**Causas comuns:**
- Imagem não existe
- ImagePullBackOff
- Probes falhando

**Solução:**

```bash
kubectl rollout undo deployment/myapp-webapi -n myapp
```

### Problema: Service não roteia tráfego

**Verificar:**

```bash
# Selectors do Service batem com labels dos Pods?
kubectl describe service myapp-webapi -n myapp
kubectl get pods -n myapp --show-labels

# Endpoints foram criados?
kubectl get endpoints myapp-webapi -n myapp
```

---

## 16) Limpeza

Ao final da live, você pode manter os recursos para a próxima live ou limpar:

```bash
# Deletar todos os recursos do namespace
kubectl delete all --all -n myapp

# Ou deletar o namespace inteiro
kubectl delete namespace myapp
```

---

## Resumo da Live 3

✅ **Aprendemos:**
- Escalar réplicas (scale up/down)
- Estratégia RollingUpdate para zero downtime
- Fazer rollout de novas versões
- Acompanhar status de deployment
- Fazer rollback em caso de problema
- Configurar health checks (readiness/liveness)
- Visualizar load balancing entre pods

✅ **Pipeline mental de "publicar com segurança":**

1. **Build** → nova imagem
2. **Push** → Docker Hub
3. **Update** → `kubectl set image` ou `kubectl apply`
4. **Watch** → `kubectl rollout status`
5. **Validate** → testar endpoints
6. **Rollback** → se algo der errado

✅ **Próxima live:** ConfigMaps, Secrets e variáveis de ambiente!

---

## Recursos adicionais

- [Kubernetes Deployments - Official Docs](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)
- [Configure Liveness, Readiness and Startup Probes](https://kubernetes.io/docs/tasks/configure-pod-container/configure-liveness-readiness-startup-probes/)
- [Deployment Strategies](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/#strategy)

---

**Dúvidas?** Compartilhe nos comentários! 🚀

