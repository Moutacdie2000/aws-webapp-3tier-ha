output "cluster_name" {
  description = "Nom du cluster ECS."
  value       = aws_ecs_cluster.this.name
}

output "cluster_arn" {
  description = "ARN du cluster ECS."
  value       = aws_ecs_cluster.this.arn
}

output "service_name" {
  description = "Nom du service ECS (utilisé par la CI/CD pour forcer un déploiement)."
  value       = aws_ecs_service.app.name
}

output "task_definition_family" {
  description = "Famille de la task definition."
  value       = aws_ecs_task_definition.app.family
}

output "ecr_repository_url" {
  description = "URL du dépôt ECR pour pousser l'image applicative."
  value       = aws_ecr_repository.app.repository_url
}

output "ecr_repository_name" {
  description = "Nom du dépôt ECR."
  value       = aws_ecr_repository.app.name
}

output "task_security_group_id" {
  description = "Identifiant du Security Group des tâches ECS."
  value       = aws_security_group.ecs_tasks.id
}

output "log_group_name" {
  description = "Nom du groupe de logs CloudWatch des conteneurs."
  value       = aws_cloudwatch_log_group.app.name
}

output "execution_role_arn" {
  description = "ARN du rôle d'exécution ECS."
  value       = aws_iam_role.execution.arn
}

output "task_role_arn" {
  description = "ARN du rôle de tâche ECS."
  value       = aws_iam_role.task.arn
}
