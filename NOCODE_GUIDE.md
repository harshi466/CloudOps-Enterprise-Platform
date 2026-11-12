# Module 8: No-Code Admin Dashboard (OutSystems or Mendix)

Goal: a no-code web app that consumes the cloud backend, is deployed, monitored, and triggered from CI/CD.

## OutSystems (Personal Environment is free)
1. Sign up at outsystems.com -> create a free personal environment -> open Service Studio.
2. **New app -> Reactive Web App** named "Expense Admin".
3. **Integrations -> REST -> Consume REST API -> Add multiple methods -> Upload `nocode/openapi.yaml`** (or paste the Ingress URL).
4. Create a *Login* screen calling `POST /api/users/login`; store the token in a Client Variable and add an `Authorization: Bearer` header in the REST *OnBeforeRequest* callback.
5. Create screens:
   * **Expenses**: List bound to `GET /api/expenses`, Add form calling `POST /api/expenses`.
   * **Dashboard**: Chart widgets bound to `GET /api/expenses/summary`; a "Forecast" card calling `POST /predict` on the API Gateway URL.
6. Click **1-Click Publish** (the app is hosted and exposed on a public URL).

## Mendix (free tier)
1. Sign up at mendix.com -> Studio Pro (or Studio) -> Blank Web App.
2. **Consumed REST Service** -> import `nocode/openapi.yaml`.
3. Build pages with Data Grid + microflows calling the REST operations; Run -> **Publish to Mendix Free Cloud**.

## Integration with monitoring, logs and CI/CD
* **Monitoring/logs:** both platforms provide built-in logs and metrics (OutSystems LifeTime / Mendix Developer Portal -> Metrics). Add an AWS *Route 53 health check* or CloudWatch Synthetics canary on the published URL, and screenshot the platform's log view.
* **CI/CD trigger:** Mendix and OutSystems expose deployment APIs/CLI. Add a GitHub Actions job that, after a successful backend deploy, calls the platform's REST endpoint (store the key as a repo secret) to redeploy the app. A minimal example step:
  ```yaml
  - name: Trigger no-code redeploy
    run: curl -fsS -X POST "${{ secrets.NOCODE_DEPLOY_HOOK_URL }}"
  ```
  Alternatively demonstrate the trigger in reverse: the no-code app calls a CI webhook (`repository_dispatch`) to start a pipeline.

## Evidence to capture
Published URL, screenshots of 3 screens, REST integration config, platform logs/metrics, the CI job run.
