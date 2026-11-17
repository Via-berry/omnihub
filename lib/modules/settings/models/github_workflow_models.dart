import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class WorkflowRun {
  const WorkflowRun({
    required this.id,
    required this.name,
    required this.headBranch,
    required this.headSha,
    required this.displayTitle,
    required this.runNumber,
    required this.event,
    required this.status,
    this.conclusion,
    required this.htmlUrl,
    required this.createdAt,
    required this.updatedAt,
    this.runStartedAt,
    this.actorName,
    this.actorAvatarUrl,
    this.jobsUrl,
  });

  final int id;
  final String name;
  final String headBranch;
  final String headSha;
  final String displayTitle;
  final int runNumber;
  final String event;
  final String status;
  final String? conclusion;
  final String htmlUrl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? runStartedAt;
  final String? actorName;
  final String? actorAvatarUrl;
  final String? jobsUrl;

  factory WorkflowRun.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    final actor = json['actor'];
    String? actorName;
    String? actorAvatarUrl;
    if (actor is Map) {
      actorName = actor['login']?.toString();
      actorAvatarUrl = actor['avatar_url']?.toString();
    }

    return WorkflowRun(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Workflow',
      headBranch: json['head_branch']?.toString() ?? 'master',
      headSha: json['head_sha']?.toString() ?? '',
      displayTitle: json['display_title']?.toString() ?? '',
      runNumber: json['run_number'] is int
          ? json['run_number'] as int
          : int.tryParse(json['run_number']?.toString() ?? '0') ?? 0,
      event: json['event']?.toString() ?? 'push',
      status: json['status']?.toString() ?? 'completed',
      conclusion: json['conclusion']?.toString(),
      htmlUrl: json['html_url']?.toString() ?? '',
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      runStartedAt: json['run_started_at'] != null ? parseDate(json['run_started_at']) : null,
      actorName: actorName,
      actorAvatarUrl: actorAvatarUrl,
      jobsUrl: json['jobs_url']?.toString(),
    );
  }

  bool get isBuilding => status == 'in_progress';
  bool get isQueued =>
      status == 'queued' || status == 'waiting' || status == 'requested' || status == 'pending';
  bool get isSuccess => status == 'completed' && conclusion == 'success';
  bool get isFailed =>
      status == 'completed' && (conclusion == 'failure' || conclusion == 'timed_out');
  bool get isCancelled => status == 'completed' && conclusion == 'cancelled';

  String get statusText {
    if (isBuilding) return '正在打包中';
    if (isQueued) return '排队等待中';
    if (isSuccess) return '构建发布成功';
    if (isFailed) return '构建打包失败';
    if (isCancelled) return '已取消';
    return conclusion ?? status;
  }

  Color get statusColor {
    if (isBuilding) return const Color(0xFF007AFF);
    if (isQueued) return const Color(0xFFFF9500);
    if (isSuccess) return const Color(0xFF34C759);
    if (isFailed) return const Color(0xFFFF3B30);
    if (isCancelled) return const Color(0xFF8E8E93);
    return const Color(0xFF8E8E93);
  }

  IconData get statusIcon {
    if (isBuilding) return Icons.autorenew_rounded;
    if (isQueued) return Icons.schedule_rounded;
    if (isSuccess) return Icons.check_circle_rounded;
    if (isFailed) return Icons.cancel_rounded;
    if (isCancelled) return Icons.remove_circle_outline_rounded;
    return Icons.help_outline_rounded;
  }

  String get shortSha => headSha.length > 7 ? headSha.substring(0, 7) : headSha;

  Duration get duration {
    final start = runStartedAt ?? createdAt;
    final end = isBuilding || isQueued ? DateTime.now() : updatedAt;
    final diff = end.difference(start);
    return diff.isNegative ? Duration.zero : diff;
  }

  String get formattedDuration {
    final d = duration;
    final minutes = d.inMinutes;
    final seconds = d.inSeconds % 60;
    if (minutes > 0) {
      return '$minutes分$seconds秒';
    }
    return '$seconds秒';
  }

  String get formattedStartTime {
    final start = runStartedAt ?? createdAt;
    final now = DateTime.now();
    if (start.year == now.year && start.month == now.month && start.day == now.day) {
      return DateFormat('HH:mm').format(start);
    }
    return DateFormat('MM-dd HH:mm').format(start);
  }

  String get timeAgo {
    final now = DateTime.now();
    final diff = now.difference(createdAt);
    if (diff.inMinutes < 1) return '刚刚';
    if (diff.inMinutes < 60) return '${diff.inMinutes}分钟前';
    if (diff.inHours < 24) return '${diff.inHours}小时前';
    if (diff.inDays < 7) return '${diff.inDays}天前';
    return DateFormat('MM-dd').format(createdAt);
  }
}

class WorkflowJob {
  const WorkflowJob({
    required this.id,
    required this.name,
    required this.status,
    this.conclusion,
    required this.startedAt,
    this.completedAt,
    required this.steps,
  });

  final int id;
  final String name;
  final String status;
  final String? conclusion;
  final DateTime startedAt;
  final DateTime? completedAt;
  final List<WorkflowStep> steps;

  factory WorkflowJob.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal() ?? DateTime.now();
      }
      return DateTime.now();
    }

    final rawSteps = json['steps'];
    final steps = <WorkflowStep>[];
    if (rawSteps is List) {
      for (final raw in rawSteps) {
        if (raw is Map) {
          steps.add(WorkflowStep.fromJson(Map<String, dynamic>.from(raw)));
        }
      }
    }

    return WorkflowJob(
      id: json['id'] is int ? json['id'] as int : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? 'Job',
      status: json['status']?.toString() ?? 'completed',
      conclusion: json['conclusion']?.toString(),
      startedAt: parseDate(json['started_at']),
      completedAt: json['completed_at'] != null ? parseDate(json['completed_at']) : null,
      steps: steps,
    );
  }

  bool get isBuilding => status == 'in_progress';
  bool get isSuccess => status == 'completed' && conclusion == 'success';
  bool get isFailed => status == 'completed' && conclusion == 'failure';
}

class WorkflowStep {
  const WorkflowStep({
    required this.name,
    required this.status,
    this.conclusion,
    required this.number,
    this.startedAt,
    this.completedAt,
  });

  final String name;
  final String status;
  final String? conclusion;
  final int number;
  final DateTime? startedAt;
  final DateTime? completedAt;

  factory WorkflowStep.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) {
      if (value is String) {
        return DateTime.tryParse(value)?.toLocal();
      }
      return null;
    }

    return WorkflowStep(
      name: json['name']?.toString() ?? 'Step',
      status: json['status']?.toString() ?? 'completed',
      conclusion: json['conclusion']?.toString(),
      number: json['number'] is int
          ? json['number'] as int
          : int.tryParse(json['number']?.toString() ?? '0') ?? 0,
      startedAt: parseDate(json['started_at']),
      completedAt: parseDate(json['completed_at']),
    );
  }

  bool get isBuilding => status == 'in_progress';
  bool get isQueued => status == 'queued' || status == 'pending';
  bool get isSuccess => status == 'completed' && conclusion == 'success';
  bool get isFailed => status == 'completed' && conclusion == 'failure';
  bool get isSkipped => status == 'completed' && conclusion == 'skipped';

  Color get statusColor {
    if (isBuilding) return const Color(0xFF007AFF);
    if (isSuccess) return const Color(0xFF34C759);
    if (isFailed) return const Color(0xFFFF3B30);
    if (isSkipped) return const Color(0xFF8E8E93);
    return const Color(0xFF8E8E93);
  }

  IconData get statusIcon {
    if (isBuilding) return Icons.autorenew_rounded;
    if (isSuccess) return Icons.check_circle_rounded;
    if (isFailed) return Icons.cancel_rounded;
    if (isSkipped) return Icons.remove_circle_outline_rounded;
    return Icons.radio_button_unchecked_rounded;
  }

  Duration? get duration {
    if (startedAt == null) return null;
    final end = completedAt ?? (isBuilding ? DateTime.now() : startedAt);
    return end?.difference(startedAt!);
  }

  String get formattedDuration {
    final d = duration;
    if (d == null) return '';
    final seconds = d.inSeconds;
    if (seconds < 60) return '${seconds}s';
    final minutes = d.inMinutes;
    final remainingSeconds = seconds % 60;
    return '${minutes}m ${remainingSeconds}s';
  }
}
