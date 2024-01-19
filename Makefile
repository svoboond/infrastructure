.PHONY: clean \
	deploy-mysql-service \
	local-dev-deploy-all-services \
	local-dev-deploy-mysql-service \
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

deploy-mysql-service:
	SITE=${SITE} skaffold run --kube-context ${SITE} -f k8s-services/mysql/skaffold.yaml

local-dev-deploy-all-services:
	$(MAKE) --no-print-directory local-dev-deploy-mysql-service

local-dev-deploy-mysql-service:
	@$(MAKE) --no-print-directory SITE=$(LOCAL_DEV_NAME) deploy-mysql-service

minikube-adminer:
	$(OPEN_BROWSER) `minikube service -n mysql-$(LOCAL_DEV_NAME) adminer --url=true`
	@minikube service -n mysql-$(LOCAL_DEV_NAME) adminer --url=true

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
