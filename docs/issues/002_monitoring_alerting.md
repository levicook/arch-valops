# Issue 002: Monitoring & Alerting Architecture

**Status**: Open  
**Priority**: Medium  
**Effort**: 3-5 days  
**Created**: 2024-12-31  

## Problem Statement

Current monitoring and alerting capabilities are basic and reactive. We have:
- ✅ Manual health checks via dashboard
- ✅ Basic systemd logging
- ✅ Some status scripts (validator-status, bitcoin-status)
- ❌ No proactive alerting
- ❌ No historical metrics collection  
- ❌ No automated remediation
- ❌ Limited observability for trend analysis

This creates operational blind spots and manual intervention requirements for production systems.

## Current State Analysis

### ✅ What Works
- **Dashboard**: `validator-dashboard` provides real-time tmux monitoring
- **Status Scripts**: Individual service status with basic health checks
- **Systemd Integration**: Service logs via journalctl
- **Health Endpoints**: RPC connectivity checks

### ❌ Gaps Identified

#### 1. **Proactive Alerting**
- No automated notifications for service failures
- No threshold-based alerts (disk space, memory, errors)
- No integration with external monitoring (PagerDuty, Slack, etc.)

#### 2. **Historical Metrics**
- No time-series data collection
- No performance trend analysis
- No capacity planning data
- No SLA/uptime tracking

#### 3. **Automated Recovery**
- Service restart happens via systemd but no intelligent recovery
- No automatic disk cleanup when space is low
- No failover mechanisms for external dependencies

#### 4. **Comprehensive Health Checks**
- Basic RPC connectivity only
- No deep health validation (sync status, peer connections, etc.)
- No dependency health (titan, bitcoin connectivity)
- No performance degradation detection

## Target Architecture

### **Monitoring Stack Options**

#### Option A: Lightweight (Prometheus + Grafana)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Service Metrics │───▶│ Prometheus      │───▶│ Grafana         │
│ - node_exporter │    │ - Time series   │    │ - Dashboards    │
│ - custom        │    │ - Alertmanager  │    │ - Visualization │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Option B: Cloud-Native (DataDog/New Relic)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Service Metrics │───▶│ Cloud Provider  │───▶│ SaaS Dashboard  │
│ - Agent-based   │    │ - Managed       │    │ - Zero config   │
│ - Push model    │    │ - Auto-scaling  │    │ - Built-in      │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

#### Option C: Hybrid (Local + Cloud)
```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│ Local Metrics   │───▶│ Local Storage   │───▶│ Cloud Export    │
│ - Critical only │    │ - Short-term    │    │ - Long-term     │
│ - High freq     │    │ - Fast alerts   │    │ - Dashboards    │
└─────────────────┘    └─────────────────┘    └─────────────────┘
```

### **Alerting Strategy**

#### **Severity Levels**
- **P0 (Critical)**: Service down, data corruption risk
- **P1 (High)**: Performance degraded, manual intervention needed  
- **P2 (Medium)**: Trends indicating future issues
- **P3 (Low)**: FYI notifications, maintenance reminders

#### **Notification Channels**
- **Immediate**: PagerDuty, SMS for P0/P1
- **Batched**: Slack, Email for P2/P3
- **Dashboard**: Always-on visual indicators

### **Key Metrics to Track**

#### **Service Health**
- Service uptime/downtime events
- Restart frequency and causes  
- RPC response times and success rates
- Error rates by category

#### **Resource Utilization**
- CPU usage patterns and spikes
- Memory consumption and leaks
- Disk space usage and growth rates
- Network I/O and connection counts

#### **Business Metrics**
- Block height sync status
- Transaction processing rates
- Peer connection stability
- Data synchronization lag

#### **Infrastructure**
- Host system health (disk, CPU, memory)
- Network connectivity to dependencies
- Certificate expiration
- Binary update availability

## Implementation Phases

### **Phase 1: Foundational Monitoring (1-2 days)**
1. **Metrics Collection**
   - Install node_exporter for system metrics
   - Add custom exporters for service-specific metrics
   - Configure Prometheus with basic service discovery

2. **Basic Alerting**
   - Service down alerts
   - Disk space threshold alerts
   - High error rate alerts

### **Phase 2: Operational Dashboards (1-2 days)**
1. **Grafana Setup**
   - Service health dashboards
   - Resource utilization views
   - Historical trend analysis

2. **Alert Routing**
   - Slack integration for non-critical alerts
   - Email notifications for trends

### **Phase 3: Advanced Features (1-2 days)**
1. **Automated Recovery**
   - Intelligent service restart logic
   - Disk cleanup automation
   - Dependency health checking

2. **Capacity Planning**
   - Growth rate analysis
   - Predictive alerting
   - Resource optimization recommendations

## Open Questions

1. **Hosting Strategy**: Self-hosted vs managed monitoring?
2. **Data Retention**: How long to keep metrics locally vs cloud?
3. **Alert Fatigue**: How to balance comprehensive monitoring with noise?
4. **Security**: How to secure monitoring infrastructure and data?
5. **Cost**: What's the budget for monitoring tools and infrastructure?

## Success Criteria

- **Proactive Detection**: 95% of issues detected before user impact
- **Mean Time to Detection**: < 2 minutes for critical issues
- **Mean Time to Recovery**: < 5 minutes for automated issues
- **False Positive Rate**: < 5% of alerts
- **Coverage**: 100% of critical services monitored

## Implementation Notes

- Start with Option A (Prometheus/Grafana) for cost-effectiveness
- Focus on P0/P1 alerts first to establish confidence
- Integrate with existing systemd-based architecture
- Leverage existing .envrc patterns for configuration
- Build on proven IaC patterns from systemd migration

---

**Next Steps**: Review with team → Choose monitoring stack → Implement Phase 1 