.PHONY: clean \
	deploy-postgres-service deploy-redis-service \
	local-dev-deploy-all-services \
	local-dev-deploy-postgres-service local-dev-deploy-redis-service \
	minikube-adminer minikube-create minikube-destroy minikube-init minikube-showall \
	proxy-clean proxy-create proxy-destroy

LOCAL_DEV_ADDONS ?= ingress
LOCAL_DEV_CPUS ?= 4
LOCAL_DEV_DRIVER ?= docker
LOCAL_DEV_MEM ?= 10g
LOCAL_DEV_NAME ?= local-dev
LOCAL_DEV_VERSION ?= stable

OPEN_BROWSER ?= xdg-open

clean: proxy-clean

deploy-postgres-service:
	SITE=${SITE} skaffold run --kube-context ${SITE} -f k8s-services/postgres/skaffold.yaml

deploy-redis-service:
	SITE=${SITE} skaffold run --kube-context ${SITE} -f k8s-services/redis/skaffold.yaml

local-dev-deploy-all-services:
	$(MAKE) --no-print-directory local-dev-deploy-postgres-service
	$(MAKE) --no-print-directory local-dev-deploy-redis-service

local-dev-deploy-postgres-service:
	@$(MAKE) --no-print-directory SITE=$(LOCAL_DEV_NAME) deploy-postgres-service

local-dev-deploy-redis-service:
	@$(MAKE) --no-print-directory SITE=$(LOCAL_DEV_NAME) deploy-redis-service

minikube-adminer:
	$(OPEN_BROWSER) `minikube service -n postgres-$(LOCAL_DEV_NAME) adminer --url=true`
	@minikube service -n postgres-$(LOCAL_DEV_NAME) adminer --url=true

minikube-create:
	minikube start --profile=$(LOCAL_DEV_NAME) --cpus=$(LOCAL_DEV_CPUS) --memory=$(LOCAL_DEV_MEM) --driver=$(LOCAL_DEV_DRIVER) --kubernetes-version=$(LOCAL_DEV_VERSION) --addons=${LOCAL_DEV_ADDONS}
	minikube profile $(LOCAL_DEV_NAME)
	@$(MAKE) --no-print-directory proxy-create

minikube-destroy: proxy-destroy
	minikube delete --profile=$(LOCAL_DEV_NAME)

minikube-init: minikube-create local-dev-deploy-all-services minikube-showall

minikube-showall:
	kubectl get all --all-namespaces

proxy-clean:
	rm -rfv docker_mirror_cache
	rm -rfv docker_mirror_certs

proxy-create:
	./scripts/proxy-create.sh $(LOCAL_DEV_NAME)

proxy-destroy:
	./scripts/proxy-destroy.sh
