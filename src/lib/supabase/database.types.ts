
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "absence_releases": {
                  Row: {
                    "absence_id": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "absence_id": string,"visit_id": string
                  }
                  Update: {
                    "absence_id"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "absence_releases_absence_id_fkey"
      columns: ["absence_id"]
isOneToOne: false
      referencedRelation: "member_absences"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "absence_releases_visit_id_fkey"
      columns: ["visit_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id"]
    }
                  ]
                },"audit_events": {
                  Row: {
                    "actor_id": string | null,"actor_role": string,"changed": NonNullable<Json>,"command": string | null,"entity_id": string,"id": number,"idempotency_key": string | null,"occurred_at": string,"organization_id": string,"table_name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"actor_role": string,"changed": NonNullable<Json>,"command"?: string | null,"entity_id": string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id": string,"table_name": string
                  }
                  Update: {
                    "actor_id"?: string | null,"actor_role"?: string,"changed"?: NonNullable<Json>,"command"?: string | null,"entity_id"?: string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id"?: string,"table_name"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "audit_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"audit_read_log": {
                  Row: {
                    "entity_id": string,"entity_type": string,"id": number,"organization_id": string | null,"purpose": string,"read_at": string,"reader_id": string,"rows_returned": number
                  }
                  ComputedFields: never
                  Insert: {
                    "entity_id": string,"entity_type": string,"id"?: never,"organization_id"?: string | null,"purpose": string,"read_at"?: string,"reader_id": string,"rows_returned": number
                  }
                  Update: {
                    "entity_id"?: string,"entity_type"?: string,"id"?: never,"organization_id"?: string | null,"purpose"?: string,"read_at"?: string,"reader_id"?: string,"rows_returned"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "audit_read_log_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"billable_facts": {
                  Row: {
                    "actual_care_minutes": number | null,"billable": boolean,"billable_minutes_a": number | null,"billable_minutes_b": number | null,"billable_minutes_c": number | null,"case_id": string,"cause": string,"created_at": string,"created_by": string,"hold_id": string | null,"id": string,"measured_care_minutes": number | null,"order_as_of": string | null,"order_basis": string,"order_recorded": Json | null,"organization_id": string,"payer_chain": NonNullable<Json>,"planned_minutes_a": number,"planned_minutes_b": number,"planned_minutes_c": number,"reasons": (string)[],"report_id": string,"rule_version": string,"snapshot_hash": string | null,"supersedes_id": string | null,"tariff_versions": NonNullable<Json>,"team_id": string,"visit_date": string,"visit_id": string,"warnings": (string)[]
                  }
                  ComputedFields: never
                  Insert: {
                    "actual_care_minutes"?: number | null,"billable": boolean,"billable_minutes_a"?: number | null,"billable_minutes_b"?: number | null,"billable_minutes_c"?: number | null,"case_id": string,"cause"?: string,"created_at"?: string,"created_by": string,"hold_id"?: string | null,"id"?: string,"measured_care_minutes"?: number | null,"order_as_of"?: string | null,"order_basis": string,"order_recorded"?: Json | null,"organization_id": string,"payer_chain": NonNullable<Json>,"planned_minutes_a"?: number,"planned_minutes_b"?: number,"planned_minutes_c"?: number,"reasons"?: (string)[],"report_id": string,"rule_version"?: string,"snapshot_hash"?: string | null,"supersedes_id"?: string | null,"tariff_versions": NonNullable<Json>,"team_id": string,"visit_date": string,"visit_id": string,"warnings"?: (string)[]
                  }
                  Update: {
                    "actual_care_minutes"?: number | null,"billable"?: boolean,"billable_minutes_a"?: number | null,"billable_minutes_b"?: number | null,"billable_minutes_c"?: number | null,"case_id"?: string,"cause"?: string,"created_at"?: string,"created_by"?: string,"hold_id"?: string | null,"id"?: string,"measured_care_minutes"?: number | null,"order_as_of"?: string | null,"order_basis"?: string,"order_recorded"?: Json | null,"organization_id"?: string,"payer_chain"?: NonNullable<Json>,"planned_minutes_a"?: number,"planned_minutes_b"?: number,"planned_minutes_c"?: number,"reasons"?: (string)[],"report_id"?: string,"rule_version"?: string,"snapshot_hash"?: string | null,"supersedes_id"?: string | null,"tariff_versions"?: NonNullable<Json>,"team_id"?: string,"visit_date"?: string,"visit_id"?: string,"warnings"?: (string)[]
                  }
                  Relationships: [
                    {
      foreignKeyName: "billable_facts_hold_id_fkey"
      columns: ["hold_id"]
isOneToOne: false
      referencedRelation: "quality_holds"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "billable_facts_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "billable_facts_report_id_fkey"
      columns: ["report_id"]
isOneToOne: false
      referencedRelation: "visit_reports"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "billable_facts_supersedes_id_fkey"
      columns: ["supersedes_id"]
isOneToOne: false
      referencedRelation: "billable_facts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "billable_facts_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"billing_rules": {
                  Row: {
                    "id": string,"min_billable_minutes": number,"region": string,"source": string,"valid_from": string,"valid_to": string | null,"validated": boolean,"validation_note": string | null,"version": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"min_billable_minutes": number,"region": string,"source": string,"valid_from": string,"valid_to"?: string | null,"validated"?: boolean,"validation_note"?: string | null,"version": string
                  }
                  Update: {
                    "id"?: string,"min_billable_minutes"?: number,"region"?: string,"source"?: string,"valid_from"?: string,"valid_to"?: string | null,"validated"?: boolean,"validation_note"?: string | null,"version"?: string
                  }
                  Relationships: [
                    
                  ]
                },"care_notes": {
                  Row: {
                    "author_name": string | null,"case_id": string | null,"content": string,"created_at": string,"id": string,"note_type": string,"organization_id": string,"status": string,"team_id": string | null,"visit_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "author_name"?: string | null,"case_id"?: string | null,"content": string,"created_at"?: string,"id"?: string,"note_type": string,"organization_id": string,"status"?: string,"team_id"?: string | null,"visit_id"?: string | null
                  }
                  Update: {
                    "author_name"?: string | null,"case_id"?: string | null,"content"?: string,"created_at"?: string,"id"?: string,"note_type"?: string,"organization_id"?: string,"status"?: string,"team_id"?: string | null,"visit_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "care_notes_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_notes_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_notes_visit_id_fkey"
      columns: ["visit_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_notes_visit_same_org"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"care_plan_items": {
                  Row: {
                    "active": boolean,"case_id": string,"category": string,"created_at": string,"created_by": string,"freq_period": string | null,"freq_times": number | null,"freq_weekdays": (number)[] | null,"frequency": string,"goal": string | null,"id": string,"organization_id": string,"planned_minutes": number,"retire_reason": string | null,"retired_at": string | null,"retired_by": string | null,"review_date": string,"service": string,"team_id": string,"window_end": string | null,"window_start": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "active"?: boolean,"case_id": string,"category": string,"created_at"?: string,"created_by": string,"freq_period"?: string | null,"freq_times"?: number | null,"freq_weekdays"?: (number)[] | null,"frequency": string,"goal"?: string | null,"id"?: string,"organization_id": string,"planned_minutes": number,"retire_reason"?: string | null,"retired_at"?: string | null,"retired_by"?: string | null,"review_date": string,"service": string,"team_id": string,"window_end"?: string | null,"window_start"?: string | null
                  }
                  Update: {
                    "active"?: boolean,"case_id"?: string,"category"?: string,"created_at"?: string,"created_by"?: string,"freq_period"?: string | null,"freq_times"?: number | null,"freq_weekdays"?: (number)[] | null,"frequency"?: string,"goal"?: string | null,"id"?: string,"organization_id"?: string,"planned_minutes"?: number,"retire_reason"?: string | null,"retired_at"?: string | null,"retired_by"?: string | null,"review_date"?: string,"service"?: string,"team_id"?: string,"window_end"?: string | null,"window_start"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "care_plan_items_case_id_organization_id_fkey"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_plan_items_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_plan_items_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"care_visits": {
                  Row: {
                    "billable": boolean | null,"case_id": string | null,"cover_team_id": string | null,"covered_at": string | null,"covered_by": string | null,"created_at": string,"id": string,"is_needs_assessment": boolean,"notes": string | null,"organization_id": string,"plan_generated": boolean,"plan_slot_date": string | null,"plan_slot_start": string | null,"planned_minutes_a": number | null,"planned_minutes_b": number | null,"planned_minutes_c": number | null,"responsible_user_id": string | null,"services_provided": (string)[] | null,"status": string | null,"suspended_at": string | null,"suspended_by": string | null,"team_id": string | null,"team_member_name": string | null,"time_end": string | null,"time_start": string | null,"visit_date": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "billable"?: boolean | null,"case_id"?: string | null,"cover_team_id"?: string | null,"covered_at"?: string | null,"covered_by"?: string | null,"created_at"?: string,"id"?: string,"is_needs_assessment"?: boolean,"notes"?: string | null,"organization_id": string,"plan_generated"?: boolean,"plan_slot_date"?: string | null,"plan_slot_start"?: string | null,"planned_minutes_a"?: number | null,"planned_minutes_b"?: number | null,"planned_minutes_c"?: number | null,"responsible_user_id"?: string | null,"services_provided"?: (string)[] | null,"status"?: string | null,"suspended_at"?: string | null,"suspended_by"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
                  }
                  Update: {
                    "billable"?: boolean | null,"case_id"?: string | null,"cover_team_id"?: string | null,"covered_at"?: string | null,"covered_by"?: string | null,"created_at"?: string,"id"?: string,"is_needs_assessment"?: boolean,"notes"?: string | null,"organization_id"?: string,"plan_generated"?: boolean,"plan_slot_date"?: string | null,"plan_slot_start"?: string | null,"planned_minutes_a"?: number | null,"planned_minutes_b"?: number | null,"planned_minutes_c"?: number | null,"responsible_user_id"?: string | null,"services_provided"?: (string)[] | null,"status"?: string | null,"suspended_at"?: string | null,"suspended_by"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "care_visits_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "care_visits_cover_team_id_fkey"
      columns: ["cover_team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_suspended_by_fkey"
      columns: ["suspended_by"]
isOneToOne: false
      referencedRelation: "case_lifecycle_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "care_visits_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"case_gp_notices": {
                  Row: {
                    "case_id": string,"channel": string,"id": string,"informed_on": string,"organization_id": string,"recorded_at": string,"recorded_by": string,"task_id": string | null,"team_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id": string,"channel": string,"id"?: string,"informed_on": string,"organization_id": string,"recorded_at"?: string,"recorded_by": string,"task_id"?: string | null,"team_id": string
                  }
                  Update: {
                    "case_id"?: string,"channel"?: string,"id"?: string,"informed_on"?: string,"organization_id"?: string,"recorded_at"?: string,"recorded_by"?: string,"task_id"?: string | null,"team_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "case_gp_notices_case_id_organization_id_fkey"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "case_gp_notices_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "case_gp_notices_task_id_fkey"
      columns: ["task_id"]
isOneToOne: false
      referencedRelation: "case_tasks"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "case_gp_notices_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"case_lifecycle_events": {
                  Row: {
                    "actor_id": string,"case_id": string,"created_at": string,"expected_end": string | null,"id": string,"idempotency_key": string,"kind": string,"note": string | null,"organization_id": string,"reason_code": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"case_id": string,"created_at"?: string,"expected_end"?: string | null,"id"?: string,"idempotency_key": string,"kind": string,"note"?: string | null,"organization_id": string,"reason_code"?: string | null
                  }
                  Update: {
                    "actor_id"?: string,"case_id"?: string,"created_at"?: string,"expected_end"?: string | null,"id"?: string,"idempotency_key"?: string,"kind"?: string,"note"?: string | null,"organization_id"?: string,"reason_code"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "case_lifecycle_events_case_id_organization_id_fkey"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "case_lifecycle_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"case_safety_alert_values": {
                  Row: {
                    "actor_id": string,"case_id": string,"category_id": string,"created_at": string,"id": string,"idempotency_key": string,"note": string | null,"organization_id": string,"seq": number,"source": string,"value": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"case_id": string,"category_id": string,"created_at"?: string,"id"?: string,"idempotency_key": string,"note"?: string | null,"organization_id": string,"seq"?: never,"source": string,"value": string
                  }
                  Update: {
                    "actor_id"?: string,"case_id"?: string,"category_id"?: string,"created_at"?: string,"id"?: string,"idempotency_key"?: string,"note"?: string | null,"organization_id"?: string,"seq"?: never,"source"?: string,"value"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "case_safety_alert_values_case_id_organization_id_fkey"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "case_safety_alert_values_category_id_fkey"
      columns: ["category_id"]
isOneToOne: false
      referencedRelation: "safety_alert_categories"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "case_safety_alert_values_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"case_tasks": {
                  Row: {
                    "case_id": string,"created_at": string,"detail": string | null,"done_at": string | null,"done_by": string | null,"id": string,"kind": string,"organization_id": string,"status": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id": string,"created_at"?: string,"detail"?: string | null,"done_at"?: string | null,"done_by"?: string | null,"id"?: string,"kind": string,"organization_id": string,"status"?: string
                  }
                  Update: {
                    "case_id"?: string,"created_at"?: string,"detail"?: string | null,"done_at"?: string | null,"done_by"?: string | null,"id"?: string,"kind"?: string,"organization_id"?: string,"status"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "case_tasks_case_id_organization_id_fkey"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "case_tasks_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"cases": {
                  Row: {
                    "access_notes": string | null,"address": string | null,"assigned_team": string | null,"assigned_team_id": string | null,"auto_planning": boolean,"bedarf": string | null,"care_level": string | null,"care_needs": (string)[] | null,"cognitive_status": string | null,"created_at": string,"date_of_birth": string | null,"deputy_nurse_id": string | null,"diagnosis_tags": (string)[] | null,"emergency_contact_name": string | null,"emergency_contact_phone": string | null,"expected_hours_per_week": number | null,"first_name": string | null,"gender": string | null,"gp_named": boolean | null,"id": string,"insurance_provider": string | null,"insurance_type": string | null,"insurer_name": string | null,"intake_consent_confirmed_at": string | null,"intake_consent_confirmed_by": string | null,"language_notes": string | null,"last_name": string | null,"lifecycle": string,"medical_order_status": string | null,"medical_order_valid_until": string | null,"mobility_status": string | null,"name": string | null,"needs_assessment_done_at": string | null,"next_step": string | null,"notes": string | null,"organization_id": string,"ort": string | null,"other_providers_active": boolean | null,"phone": string | null,"plan_generated_on": string | null,"plz": string | null,"previous_case_id": string | null,"primary_nurse_id": string | null,"proposed_primary_nurse_id": string | null,"ready_for_matching_at": string | null,"referral_source": string | null,"region": string | null,"reopened_at": string | null,"requested_start": string | null,"residence_canton": string | null,"residence_municipality": string | null,"source_partner_request_id": string | null,"start_date": string | null,"status": string | null,"time_info": string | null,"urgency": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "access_notes"?: string | null,"address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"auto_planning"?: boolean,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"deputy_nurse_id"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"expected_hours_per_week"?: number | null,"first_name"?: string | null,"gender"?: string | null,"gp_named"?: boolean | null,"id"?: string,"insurance_provider"?: string | null,"insurance_type"?: string | null,"insurer_name"?: string | null,"intake_consent_confirmed_at"?: string | null,"intake_consent_confirmed_by"?: string | null,"language_notes"?: string | null,"last_name"?: string | null,"lifecycle"?: string,"medical_order_status"?: string | null,"medical_order_valid_until"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"needs_assessment_done_at"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id": string,"ort"?: string | null,"other_providers_active"?: boolean | null,"phone"?: string | null,"plan_generated_on"?: string | null,"plz"?: string | null,"previous_case_id"?: string | null,"primary_nurse_id"?: string | null,"proposed_primary_nurse_id"?: string | null,"ready_for_matching_at"?: string | null,"referral_source"?: string | null,"region"?: string | null,"reopened_at"?: string | null,"requested_start"?: string | null,"residence_canton"?: string | null,"residence_municipality"?: string | null,"source_partner_request_id"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
                  }
                  Update: {
                    "access_notes"?: string | null,"address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"auto_planning"?: boolean,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"deputy_nurse_id"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"expected_hours_per_week"?: number | null,"first_name"?: string | null,"gender"?: string | null,"gp_named"?: boolean | null,"id"?: string,"insurance_provider"?: string | null,"insurance_type"?: string | null,"insurer_name"?: string | null,"intake_consent_confirmed_at"?: string | null,"intake_consent_confirmed_by"?: string | null,"language_notes"?: string | null,"last_name"?: string | null,"lifecycle"?: string,"medical_order_status"?: string | null,"medical_order_valid_until"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"needs_assessment_done_at"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id"?: string,"ort"?: string | null,"other_providers_active"?: boolean | null,"phone"?: string | null,"plan_generated_on"?: string | null,"plz"?: string | null,"previous_case_id"?: string | null,"primary_nurse_id"?: string | null,"proposed_primary_nurse_id"?: string | null,"ready_for_matching_at"?: string | null,"referral_source"?: string | null,"region"?: string | null,"reopened_at"?: string | null,"requested_start"?: string | null,"residence_canton"?: string | null,"residence_municipality"?: string | null,"source_partner_request_id"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "cases_assigned_team_id_fkey"
      columns: ["assigned_team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cases_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cases_previous_same_org"
      columns: ["previous_case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "cases_source_request_same_org"
      columns: ["source_partner_request_id","organization_id"]
isOneToOne: false
      referencedRelation: "partner_requests"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "cases_team_same_org"
      columns: ["assigned_team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"change_log": {
                  Row: {
                    "actor_id": string,"changes": NonNullable<Json>,"command": string,"created_at": string,"entity_id": string,"entity_table": string,"id": number,"idempotency_key": string,"organization_id": string,"reason": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"changes": NonNullable<Json>,"command": string,"created_at"?: string,"entity_id": string,"entity_table": string,"id"?: never,"idempotency_key": string,"organization_id": string,"reason": string
                  }
                  Update: {
                    "actor_id"?: string,"changes"?: NonNullable<Json>,"command"?: string,"created_at"?: string,"entity_id"?: string,"entity_table"?: string,"id"?: never,"idempotency_key"?: string,"organization_id"?: string,"reason"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "change_log_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"cover_events": {
                  Row: {
                    "created_at": string,"id": string,"kind": string,"nurse_id": string | null,"organization_id": string,"reason": string | null,"seq": number,"team_id": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"kind": string,"nurse_id"?: string | null,"organization_id": string,"reason"?: string | null,"seq"?: never,"team_id"?: string | null,"visit_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"kind"?: string,"nurse_id"?: string | null,"organization_id"?: string,"reason"?: string | null,"seq"?: never,"team_id"?: string | null,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "cover_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "cover_events_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"cover_settings": {
                  Row: {
                    "cover_enabled": boolean,"fallback_lead_hours": number,"id": string,"offer_lead_hours": number,"organization_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "cover_enabled"?: boolean,"fallback_lead_hours": number,"id"?: string,"offer_lead_hours": number,"organization_id"?: string | null
                  }
                  Update: {
                    "cover_enabled"?: boolean,"fallback_lead_hours"?: number,"id"?: string,"offer_lead_hours"?: number,"organization_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "cover_settings_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: true
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"exception_events": {
                  Row: {
                    "actor_id": string | null,"created_at": string,"exception_key": string,"id": number,"idempotency_key": string | null,"kind": string,"organization_id": string,"text": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"created_at"?: string,"exception_key": string,"id"?: never,"idempotency_key"?: string | null,"kind": string,"organization_id": string,"text"?: string | null
                  }
                  Update: {
                    "actor_id"?: string | null,"created_at"?: string,"exception_key"?: string,"id"?: never,"idempotency_key"?: string | null,"kind"?: string,"organization_id"?: string,"text"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "exception_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"exception_rule_overrides": {
                  Row: {
                    "amount": number | null,"escalate_to_p1_after_hours": number | null,"exception_type": string,"id": string,"organization_id": string,"priority": string,"updated_at": string,"updated_by": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount"?: number | null,"escalate_to_p1_after_hours"?: number | null,"exception_type": string,"id"?: string,"organization_id": string,"priority": string,"updated_at"?: string,"updated_by": string
                  }
                  Update: {
                    "amount"?: number | null,"escalate_to_p1_after_hours"?: number | null,"exception_type"?: string,"id"?: string,"organization_id"?: string,"priority"?: string,"updated_at"?: string,"updated_by"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "exception_rule_overrides_exception_type_fkey"
      columns: ["exception_type"]
isOneToOne: false
      referencedRelation: "exception_rules"
      referencedColumns: ["exception_type"]
    },{
      foreignKeyName: "exception_rule_overrides_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"exception_rules": {
                  Row: {
                    "amount": number | null,"amount_direction": string | null,"escalate_to_p1_after_hours": number | null,"exception_type": string,"label": string,"next_step": string,"priority": string,"unit": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount"?: number | null,"amount_direction"?: string | null,"escalate_to_p1_after_hours"?: number | null,"exception_type": string,"label": string,"next_step": string,"priority": string,"unit"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "amount"?: number | null,"amount_direction"?: string | null,"escalate_to_p1_after_hours"?: number | null,"exception_type"?: string,"label"?: string,"next_step"?: string,"priority"?: string,"unit"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    
                  ]
                },"handover_settings": {
                  Row: {
                    "id": string,"lookback_visits": number,"organization_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"lookback_visits": number,"organization_id"?: string | null
                  }
                  Update: {
                    "id"?: string,"lookback_visits"?: number,"organization_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "handover_settings_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: true
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"handover_shown": {
                  Row: {
                    "created_at": string,"entries": NonNullable<Json>,"entry_count": number,"id": number,"nurse_id": string,"organization_id": string,"rule": string,"since_at": string,"visit_event_id": number,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"entries": NonNullable<Json>,"entry_count": number,"id"?: never,"nurse_id": string,"organization_id": string,"rule": string,"since_at": string,"visit_event_id": number,"visit_id": string
                  }
                  Update: {
                    "created_at"?: string,"entries"?: NonNullable<Json>,"entry_count"?: number,"id"?: never,"nurse_id"?: string,"organization_id"?: string,"rule"?: string,"since_at"?: string,"visit_event_id"?: number,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "handover_shown_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "handover_shown_visit_event_id_fkey"
      columns: ["visit_event_id"]
isOneToOne: true
      referencedRelation: "visit_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "handover_shown_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"match_candidates": {
                  Row: {
                    "created_at": string,"distance_km": number | null,"fit_score": number,"id": string,"matching_request_id": string | null,"open_slots": number | null,"organization_id": string,"reasons": (string)[] | null,"status": string,"team_id": string | null,"utilization": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"distance_km"?: number | null,"fit_score"?: number,"id"?: string,"matching_request_id"?: string | null,"open_slots"?: number | null,"organization_id": string,"reasons"?: (string)[] | null,"status"?: string,"team_id"?: string | null,"utilization"?: number | null
                  }
                  Update: {
                    "created_at"?: string,"distance_km"?: number | null,"fit_score"?: number,"id"?: string,"matching_request_id"?: string | null,"open_slots"?: number | null,"organization_id"?: string,"reasons"?: (string)[] | null,"status"?: string,"team_id"?: string | null,"utilization"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "match_candidates_matching_request_id_fkey"
      columns: ["matching_request_id"]
isOneToOne: false
      referencedRelation: "matching_requests"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_request_same_org"
      columns: ["matching_request_id","organization_id"]
isOneToOne: false
      referencedRelation: "matching_requests"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "match_candidates_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "match_candidates_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"matching_requests": {
                  Row: {
                    "case_id": string | null,"created_at": string,"first_refusal_until": string | null,"id": string,"notes": string | null,"organization_id": string,"preferred_team_id": string | null,"referral_type": string | null,"region": string,"request_title": string,"required_qualification": string | null,"required_services": (string)[] | null,"response_due_at": string | null,"selected_team_id": string | null,"status": string,"urgency": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"created_at"?: string,"first_refusal_until"?: string | null,"id"?: string,"notes"?: string | null,"organization_id": string,"preferred_team_id"?: string | null,"referral_type"?: string | null,"region": string,"request_title": string,"required_qualification"?: string | null,"required_services"?: (string)[] | null,"response_due_at"?: string | null,"selected_team_id"?: string | null,"status"?: string,"urgency": string
                  }
                  Update: {
                    "case_id"?: string | null,"created_at"?: string,"first_refusal_until"?: string | null,"id"?: string,"notes"?: string | null,"organization_id"?: string,"preferred_team_id"?: string | null,"referral_type"?: string | null,"region"?: string,"request_title"?: string,"required_qualification"?: string | null,"required_services"?: (string)[] | null,"response_due_at"?: string | null,"selected_team_id"?: string | null,"status"?: string,"urgency"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "matching_requests_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "matching_requests_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_preferred_same_org"
      columns: ["preferred_team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "matching_requests_selected_team_id_fkey"
      columns: ["selected_team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "matching_requests_team_same_org"
      columns: ["selected_team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"member_absences": {
                  Row: {
                    "absence_group": string,"created_at": string,"ends_at": string,"id": string,"organization_id": string,"recorded_by": string,"starts_at": string,"team_id": string,"user_id": string,"withdrawn_at": string | null,"withdrawn_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "absence_group": string,"created_at"?: string,"ends_at": string,"id"?: string,"organization_id": string,"recorded_by": string,"starts_at": string,"team_id": string,"user_id": string,"withdrawn_at"?: string | null,"withdrawn_by"?: string | null
                  }
                  Update: {
                    "absence_group"?: string,"created_at"?: string,"ends_at"?: string,"id"?: string,"organization_id"?: string,"recorded_by"?: string,"starts_at"?: string,"team_id"?: string,"user_id"?: string,"withdrawn_at"?: string | null,"withdrawn_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "member_absences_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "member_absences_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"member_access_events": {
                  Row: {
                    "actor_id": string,"created_at": string,"id": string,"kind": string,"organization_id": string,"reason_code": string,"seq": number,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"created_at"?: string,"id"?: string,"kind": string,"organization_id": string,"reason_code": string,"seq"?: never,"user_id": string
                  }
                  Update: {
                    "actor_id"?: string,"created_at"?: string,"id"?: string,"kind"?: string,"organization_id"?: string,"reason_code"?: string,"seq"?: never,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "member_access_events_organization_id_user_id_fkey"
      columns: ["organization_id","user_id"]
isOneToOne: false
      referencedRelation: "organization_memberships"
      referencedColumns: ["organization_id","user_id"]
    }
                  ]
                },"member_invitations": {
                  Row: {
                    "accepted_at": string | null,"accepted_user": string | null,"created_at": string,"display_name": string,"email": string,"expires_at": string,"id": string,"invited_by": string,"organization_id": string,"qualification": string | null,"revoked_at": string | null,"role": string,"team_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "accepted_at"?: string | null,"accepted_user"?: string | null,"created_at"?: string,"display_name": string,"email": string,"expires_at"?: string,"id"?: string,"invited_by": string,"organization_id": string,"qualification"?: string | null,"revoked_at"?: string | null,"role": string,"team_id"?: string | null
                  }
                  Update: {
                    "accepted_at"?: string | null,"accepted_user"?: string | null,"created_at"?: string,"display_name"?: string,"email"?: string,"expires_at"?: string,"id"?: string,"invited_by"?: string,"organization_id"?: string,"qualification"?: string | null,"revoked_at"?: string | null,"role"?: string,"team_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "member_invitations_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "member_invitations_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"member_profiles": {
                  Row: {
                    "display_name": string,"id": string,"organization_id": string,"updated_at": string,"updated_by": string | null,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "display_name": string,"id"?: string,"organization_id": string,"updated_at"?: string,"updated_by"?: string | null,"user_id": string
                  }
                  Update: {
                    "display_name"?: string,"id"?: string,"organization_id"?: string,"updated_at"?: string,"updated_by"?: string | null,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "member_profiles_organization_id_user_id_fkey"
      columns: ["organization_id","user_id"]
isOneToOne: true
      referencedRelation: "organization_memberships"
      referencedColumns: ["organization_id","user_id"]
    }
                  ]
                },"organization_memberships": {
                  Row: {
                    "created_at": string,"organization_id": string,"role": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"organization_id": string,"role": string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"organization_id"?: string,"role"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "organization_memberships_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"organization_push_settings": {
                  Row: {
                    "enabled": boolean,"enabled_since": string | null,"id": string,"organization_id": string,"updated_at": string,"updated_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "enabled"?: boolean,"enabled_since"?: string | null,"id"?: string,"organization_id": string,"updated_at"?: string,"updated_by"?: string | null
                  }
                  Update: {
                    "enabled"?: boolean,"enabled_since"?: string | null,"id"?: string,"organization_id"?: string,"updated_at"?: string,"updated_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "organization_push_settings_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: true
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"organization_watched_hours": {
                  Row: {
                    "created_at": string,"created_by": string | null,"ends": string,"id": string,"organization_id": string,"starts": string,"weekday": number
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"created_by"?: string | null,"ends": string,"id"?: string,"organization_id": string,"starts": string,"weekday": number
                  }
                  Update: {
                    "created_at"?: string,"created_by"?: string | null,"ends"?: string,"id"?: string,"organization_id"?: string,"starts"?: string,"weekday"?: number
                  }
                  Relationships: [
                    {
      foreignKeyName: "organization_watched_hours_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"organizations": {
                  Row: {
                    "created_at": string,"id": string,"name": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"name": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"name"?: string
                  }
                  Relationships: [
                    
                  ]
                },"partner_requests": {
                  Row: {
                    "city": string | null,"converted_case_id": string | null,"created_at": string,"id": string,"need_summary": string,"notes": string | null,"organization_id": string,"partner_name": string,"partner_type": string | null,"region": string,"request_title": string,"requested_services": (string)[] | null,"status": string,"time_info": string | null,"urgency": string
                  }
                  ComputedFields: never
                  Insert: {
                    "city"?: string | null,"converted_case_id"?: string | null,"created_at"?: string,"id"?: string,"need_summary": string,"notes"?: string | null,"organization_id": string,"partner_name": string,"partner_type"?: string | null,"region": string,"request_title": string,"requested_services"?: (string)[] | null,"status"?: string,"time_info"?: string | null,"urgency": string
                  }
                  Update: {
                    "city"?: string | null,"converted_case_id"?: string | null,"created_at"?: string,"id"?: string,"need_summary"?: string,"notes"?: string | null,"organization_id"?: string,"partner_name"?: string,"partner_type"?: string | null,"region"?: string,"request_title"?: string,"requested_services"?: (string)[] | null,"status"?: string,"time_info"?: string | null,"urgency"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "partner_requests_case_same_org"
      columns: ["converted_case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "partner_requests_converted_case_id_fkey"
      columns: ["converted_case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "partner_requests_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"plan_slot_skips": {
                  Row: {
                    "actor_id": string | null,"case_id": string,"created_at": string,"id": string,"organization_id": string,"slot_date": string,"slot_start": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"case_id": string,"created_at"?: string,"id"?: string,"organization_id": string,"slot_date": string,"slot_start": string
                  }
                  Update: {
                    "actor_id"?: string | null,"case_id"?: string,"created_at"?: string,"id"?: string,"organization_id"?: string,"slot_date"?: string,"slot_start"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "plan_slot_skips_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"push_subscriptions": {
                  Row: {
                    "auth_secret": string,"claimed_at": string | null,"created_at": string,"endpoint": string,"id": string,"last_result": string | null,"last_sent_at": string | null,"organization_id": string,"p256dh": string,"test_requested_at": string | null,"user_id": string,"vendor": string
                  }
                  ComputedFields: never
                  Insert: {
                    "auth_secret": string,"claimed_at"?: string | null,"created_at"?: string,"endpoint": string,"id"?: string,"last_result"?: string | null,"last_sent_at"?: string | null,"organization_id": string,"p256dh": string,"test_requested_at"?: string | null,"user_id": string,"vendor": string
                  }
                  Update: {
                    "auth_secret"?: string,"claimed_at"?: string | null,"created_at"?: string,"endpoint"?: string,"id"?: string,"last_result"?: string | null,"last_sent_at"?: string | null,"organization_id"?: string,"p256dh"?: string,"test_requested_at"?: string | null,"user_id"?: string,"vendor"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "push_subscriptions_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "push_subscriptions_vendor_fkey"
      columns: ["vendor"]
isOneToOne: false
      referencedRelation: "push_vendors"
      referencedColumns: ["vendor"]
    }
                  ]
                },"push_vendors": {
                  Row: {
                    "country": string,"dpf_read_on": string | null,"dpf_swiss_status": string | null,"hosts_exact": (string)[],"hosts_suffix": (string)[],"legal_entity": string,"vendor": string
                  }
                  ComputedFields: never
                  Insert: {
                    "country": string,"dpf_read_on"?: string | null,"dpf_swiss_status"?: string | null,"hosts_exact"?: (string)[],"hosts_suffix"?: (string)[],"legal_entity": string,"vendor": string
                  }
                  Update: {
                    "country"?: string,"dpf_read_on"?: string | null,"dpf_swiss_status"?: string | null,"hosts_exact"?: (string)[],"hosts_suffix"?: (string)[],"legal_entity"?: string,"vendor"?: string
                  }
                  Relationships: [
                    
                  ]
                },"quality_event_log": {
                  Row: {
                    "actor_id": string,"created_at": string,"event_id": string,"from_status": string | null,"id": number,"idempotency_key": string,"note": string | null,"organization_id": string,"to_status": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"created_at"?: string,"event_id": string,"from_status"?: string | null,"id"?: never,"idempotency_key": string,"note"?: string | null,"organization_id": string,"to_status": string
                  }
                  Update: {
                    "actor_id"?: string,"created_at"?: string,"event_id"?: string,"from_status"?: string | null,"id"?: never,"idempotency_key"?: string,"note"?: string | null,"organization_id"?: string,"to_status"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "quality_event_log_event_id_fkey"
      columns: ["event_id"]
isOneToOne: false
      referencedRelation: "quality_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_event_log_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"quality_event_types": {
                  Row: {
                    "active": boolean,"approved_by": string,"code": string,"label": string,"serious_default": boolean,"sets_hold": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "active"?: boolean,"approved_by": string,"code": string,"label": string,"serious_default": boolean,"sets_hold": boolean
                  }
                  Update: {
                    "active"?: boolean,"approved_by"?: string,"code"?: string,"label"?: string,"serious_default"?: boolean,"sets_hold"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"quality_events": {
                  Row: {
                    "author_id": string | null,"case_id": string | null,"closed_at": string | null,"closing_note": string | null,"created_at": string,"description": string | null,"event_type": string,"id": string,"occurred_at": string | null,"organization_id": string,"owner_id": string | null,"severity": string,"status": string,"team_id": string | null,"title": string,"visit_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "author_id"?: string | null,"case_id"?: string | null,"closed_at"?: string | null,"closing_note"?: string | null,"created_at"?: string,"description"?: string | null,"event_type": string,"id"?: string,"occurred_at"?: string | null,"organization_id": string,"owner_id"?: string | null,"severity": string,"status"?: string,"team_id"?: string | null,"title": string,"visit_id"?: string | null
                  }
                  Update: {
                    "author_id"?: string | null,"case_id"?: string | null,"closed_at"?: string | null,"closing_note"?: string | null,"created_at"?: string,"description"?: string | null,"event_type"?: string,"id"?: string,"occurred_at"?: string | null,"organization_id"?: string,"owner_id"?: string | null,"severity"?: string,"status"?: string,"team_id"?: string | null,"title"?: string,"visit_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "quality_events_case_id_fkey"
      columns: ["case_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_case_same_org"
      columns: ["case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "quality_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_team_same_org"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "quality_events_visit_id_fkey"
      columns: ["visit_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_events_visit_same_org"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"quality_holds": {
                  Row: {
                    "event_id": string | null,"id": string,"idempotency_key": string,"lift_reason": string | null,"lifted_at": string | null,"lifted_by": string | null,"organization_id": string,"reason": string,"set_at": string,"set_by": string,"team_id": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "event_id"?: string | null,"id"?: string,"idempotency_key": string,"lift_reason"?: string | null,"lifted_at"?: string | null,"lifted_by"?: string | null,"organization_id": string,"reason": string,"set_at"?: string,"set_by": string,"team_id": string,"visit_id": string
                  }
                  Update: {
                    "event_id"?: string | null,"id"?: string,"idempotency_key"?: string,"lift_reason"?: string | null,"lifted_at"?: string | null,"lifted_by"?: string | null,"organization_id"?: string,"reason"?: string,"set_at"?: string,"set_by"?: string,"team_id"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "quality_holds_event_id_fkey"
      columns: ["event_id"]
isOneToOne: false
      referencedRelation: "quality_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_holds_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "quality_holds_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "quality_holds_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"referral_links": {
                  Row: {
                    "actor_id": string,"created_at": string,"id": string,"idempotency_key": string,"kind": string,"linked_case_id": string,"new_case_id": string | null,"organization_id": string,"partner_request_id": string,"reason": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"created_at"?: string,"id"?: string,"idempotency_key": string,"kind": string,"linked_case_id": string,"new_case_id"?: string | null,"organization_id": string,"partner_request_id": string,"reason": string
                  }
                  Update: {
                    "actor_id"?: string,"created_at"?: string,"id"?: string,"idempotency_key"?: string,"kind"?: string,"linked_case_id"?: string,"new_case_id"?: string | null,"organization_id"?: string,"partner_request_id"?: string,"reason"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "referral_links_linked_case_id_organization_id_fkey"
      columns: ["linked_case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "referral_links_new_case_id_organization_id_fkey"
      columns: ["new_case_id","organization_id"]
isOneToOne: false
      referencedRelation: "cases"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "referral_links_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "referral_links_partner_request_id_fkey"
      columns: ["partner_request_id"]
isOneToOne: true
      referencedRelation: "partner_requests"
      referencedColumns: ["id"]
    }
                  ]
                },"response_deadlines": {
                  Row: {
                    "amount": number,"id": string,"organization_id": string | null,"referral_type": string,"unit": string,"updated_at": string,"updated_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"id"?: string,"organization_id"?: string | null,"referral_type": string,"unit": string,"updated_at"?: string,"updated_by"?: string | null
                  }
                  Update: {
                    "amount"?: number,"id"?: string,"organization_id"?: string | null,"referral_type"?: string,"unit"?: string,"updated_at"?: string,"updated_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "response_deadlines_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"return_settings": {
                  Row: {
                    "first_refusal_hours_discharge": number,"first_refusal_hours_other": number,"id": string,"link_closed_days": number,"organization_id": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "first_refusal_hours_discharge": number,"first_refusal_hours_other": number,"id"?: string,"link_closed_days": number,"organization_id"?: string | null
                  }
                  Update: {
                    "first_refusal_hours_discharge"?: number,"first_refusal_hours_other"?: number,"id"?: string,"link_closed_days"?: number,"organization_id"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "return_settings_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: true
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"safety_alert_categories": {
                  Row: {
                    "active_from": string,"approval_ref": string | null,"class": string,"code": string,"created_at": string,"help_text": string | null,"id": string,"label": string,"refuses_codes": boolean,"source": string,"version": number,"withdrawn": boolean
                  }
                  ComputedFields: never
                  Insert: {
                    "active_from": string,"approval_ref"?: string | null,"class": string,"code": string,"created_at"?: string,"help_text"?: string | null,"id"?: string,"label": string,"refuses_codes"?: boolean,"source": string,"version": number,"withdrawn"?: boolean
                  }
                  Update: {
                    "active_from"?: string,"approval_ref"?: string | null,"class"?: string,"code"?: string,"created_at"?: string,"help_text"?: string | null,"id"?: string,"label"?: string,"refuses_codes"?: boolean,"source"?: string,"version"?: number,"withdrawn"?: boolean
                  }
                  Relationships: [
                    
                  ]
                },"safety_signals": {
                  Row: {
                    "created_at": string,"ended_at": string | null,"escalated_at": string | null,"exception_key": string,"id": string,"organization_id": string,"outside_none_at": string | null,"p1_at": string,"signal_kind": string,"taken_at": string | null,"taken_by": string | null,"team_id": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"ended_at"?: string | null,"escalated_at"?: string | null,"exception_key": string,"id"?: string,"organization_id": string,"outside_none_at"?: string | null,"p1_at": string,"signal_kind": string,"taken_at"?: string | null,"taken_by"?: string | null,"team_id": string,"visit_id": string
                  }
                  Update: {
                    "created_at"?: string,"ended_at"?: string | null,"escalated_at"?: string | null,"exception_key"?: string,"id"?: string,"organization_id"?: string,"outside_none_at"?: string | null,"p1_at"?: string,"signal_kind"?: string,"taken_at"?: string | null,"taken_by"?: string | null,"team_id"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "safety_signals_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "safety_signals_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"signal_deliveries": {
                  Row: {
                    "created_at": string,"id": string,"organization_id": string,"reason": string,"recipient_id": string,"signal_id": string,"signal_kind": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"id"?: string,"organization_id": string,"reason": string,"recipient_id": string,"signal_id": string,"signal_kind": string,"visit_id": string
                  }
                  Update: {
                    "created_at"?: string,"id"?: string,"organization_id"?: string,"reason"?: string,"recipient_id"?: string,"signal_id"?: string,"signal_kind"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "signal_deliveries_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "signal_deliveries_signal_id_fkey"
      columns: ["signal_id"]
isOneToOne: false
      referencedRelation: "safety_signals"
      referencedColumns: ["id"]
    }
                  ]
                },"signal_outside_deliveries": {
                  Row: {
                    "claimed_at": string | null,"decided_at": string,"failure": string | null,"id": string,"organization_id": string,"recipient_id": string,"result": string,"sent_at": string | null,"signal_id": string,"tapped_at": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "claimed_at"?: string | null,"decided_at"?: string,"failure"?: string | null,"id": string,"organization_id": string,"recipient_id": string,"result": string,"sent_at"?: string | null,"signal_id": string,"tapped_at"?: string | null
                  }
                  Update: {
                    "claimed_at"?: string | null,"decided_at"?: string,"failure"?: string | null,"id"?: string,"organization_id"?: string,"recipient_id"?: string,"result"?: string,"sent_at"?: string | null,"signal_id"?: string,"tapped_at"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "signal_outside_deliveries_id_fkey"
      columns: ["id"]
isOneToOne: true
      referencedRelation: "signal_deliveries"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "signal_outside_deliveries_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "signal_outside_deliveries_signal_id_fkey"
      columns: ["signal_id"]
isOneToOne: false
      referencedRelation: "safety_signals"
      referencedColumns: ["id"]
    }
                  ]
                },"signal_takes": {
                  Row: {
                    "id": string,"organization_id": string,"qualification": string | null,"signal_id": string,"stops_escalation": boolean,"taken_at": string,"taker_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"organization_id": string,"qualification"?: string | null,"signal_id": string,"stops_escalation": boolean,"taken_at"?: string,"taker_id": string
                  }
                  Update: {
                    "id"?: string,"organization_id"?: string,"qualification"?: string | null,"signal_id"?: string,"stops_escalation"?: boolean,"taken_at"?: string,"taker_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "signal_takes_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "signal_takes_signal_id_fkey"
      columns: ["signal_id"]
isOneToOne: false
      referencedRelation: "safety_signals"
      referencedColumns: ["id"]
    }
                  ]
                },"tariff_rates": {
                  Row: {
                    "amount": number,"category": string | null,"id": string,"payer": string,"region": string,"source": string,"unit": string,"valid_from": string,"valid_to": string | null,"validated": boolean,"validation_note": string | null,"version": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"category"?: string | null,"id"?: string,"payer": string,"region": string,"source": string,"unit": string,"valid_from": string,"valid_to"?: string | null,"validated"?: boolean,"validation_note"?: string | null,"version": string
                  }
                  Update: {
                    "amount"?: number,"category"?: string | null,"id"?: string,"payer"?: string,"region"?: string,"source"?: string,"unit"?: string,"valid_from"?: string,"valid_to"?: string | null,"validated"?: boolean,"validation_note"?: string | null,"version"?: string
                  }
                  Relationships: [
                    
                  ]
                },"team_decisions": {
                  Row: {
                    "actor_id": string,"case_id": string | null,"decided_at": string,"decision": string,"id": string,"idempotency_key": string,"matching_request_id": string,"organization_id": string,"reason": string | null,"reason_code": string | null,"team_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"case_id"?: string | null,"decided_at"?: string,"decision": string,"id"?: string,"idempotency_key": string,"matching_request_id": string,"organization_id": string,"reason"?: string | null,"reason_code"?: string | null,"team_id": string
                  }
                  Update: {
                    "actor_id"?: string,"case_id"?: string | null,"decided_at"?: string,"decision"?: string,"id"?: string,"idempotency_key"?: string,"matching_request_id"?: string,"organization_id"?: string,"reason"?: string | null,"reason_code"?: string | null,"team_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "team_decisions_matching_request_id_organization_id_fkey"
      columns: ["matching_request_id","organization_id"]
isOneToOne: false
      referencedRelation: "matching_requests"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "team_decisions_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "team_decisions_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"team_memberships": {
                  Row: {
                    "created_at": string,"qualification": string,"team_id": string,"user_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "created_at"?: string,"qualification": string,"team_id": string,"user_id": string
                  }
                  Update: {
                    "created_at"?: string,"qualification"?: string,"team_id"?: string,"user_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "team_memberships_team_id_fkey"
      columns: ["team_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id"]
    }
                  ]
                },"teams": {
                  Row: {
                    "care_focus": string | null,"coach_name": string | null,"created_at": string,"deactivated_at": string | null,"id": string,"lead_name": string | null,"name": string,"next_step": string | null,"open_slots": number | null,"organization_id": string,"priority": boolean | null,"region": string | null,"status": string | null,"utilization": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"deactivated_at"?: string | null,"id"?: string,"lead_name"?: string | null,"name": string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id": string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
                  }
                  Update: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"deactivated_at"?: string | null,"id"?: string,"lead_name"?: string | null,"name"?: string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id"?: string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "teams_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"visit_events": {
                  Row: {
                    "actor_id": string | null,"command": string | null,"event_type": string,"from_status": string,"id": number,"idempotency_key": string | null,"occurred_at": string,"organization_id": string,"team_id": string | null,"to_status": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id"?: string | null,"command"?: string | null,"event_type": string,"from_status": string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id": string,"team_id"?: string | null,"to_status": string,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string | null,"command"?: string | null,"event_type"?: string,"from_status"?: string,"id"?: never,"idempotency_key"?: string | null,"occurred_at"?: string,"organization_id"?: string,"team_id"?: string | null,"to_status"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_events_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_events_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_observations": {
                  Row: {
                    "author_id": string,"case_id": string | null,"content": string,"for_handover": boolean,"id": string,"idempotency_key": string,"organization_id": string,"recorded_at": string,"source": string,"supersedes_id": string | null,"team_id": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "author_id": string,"case_id"?: string | null,"content": string,"for_handover"?: boolean,"id"?: string,"idempotency_key": string,"organization_id": string,"recorded_at"?: string,"source"?: string,"supersedes_id"?: string | null,"team_id": string,"visit_id": string
                  }
                  Update: {
                    "author_id"?: string,"case_id"?: string | null,"content"?: string,"for_handover"?: boolean,"id"?: string,"idempotency_key"?: string,"organization_id"?: string,"recorded_at"?: string,"source"?: string,"supersedes_id"?: string | null,"team_id"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_observations_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_observations_supersedes_id_fkey"
      columns: ["supersedes_id"]
isOneToOne: false
      referencedRelation: "visit_observations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_observations_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "visit_observations_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_plan_changes": {
                  Row: {
                    "actor_id": string,"after": Json | null,"before": Json | null,"case_id": string | null,"change": string,"changed_at": string,"id": number,"organization_id": string,"reason": string | null,"responsible_absent": boolean,"team_id": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"after"?: Json | null,"before"?: Json | null,"case_id"?: string | null,"change": string,"changed_at"?: string,"id"?: never,"organization_id": string,"reason"?: string | null,"responsible_absent"?: boolean,"team_id"?: string | null,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"after"?: Json | null,"before"?: Json | null,"case_id"?: string | null,"change"?: string,"changed_at"?: string,"id"?: never,"organization_id"?: string,"reason"?: string | null,"responsible_absent"?: boolean,"team_id"?: string | null,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_plan_changes_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    }
                  ]
                },"visit_report_returns": {
                  Row: {
                    "id": string,"organization_id": string,"performer_id": string,"performer_unavailable": boolean,"reason": string,"report_id": string,"report_version": number,"returned_at": string,"returned_by": string,"snapshot_hash": string,"team_id": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"organization_id": string,"performer_id": string,"performer_unavailable"?: boolean,"reason": string,"report_id": string,"report_version": number,"returned_at"?: string,"returned_by": string,"snapshot_hash": string,"team_id": string,"visit_id": string
                  }
                  Update: {
                    "id"?: string,"organization_id"?: string,"performer_id"?: string,"performer_unavailable"?: boolean,"reason"?: string,"report_id"?: string,"report_version"?: number,"returned_at"?: string,"returned_by"?: string,"snapshot_hash"?: string,"team_id"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_report_returns_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_report_returns_report_id_fkey"
      columns: ["report_id"]
isOneToOne: true
      referencedRelation: "visit_reports"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_report_returns_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "visit_report_returns_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_reports": {
                  Row: {
                    "case_id": string | null,"correction_reason": string | null,"countersign_required": boolean,"countersigned_at": string | null,"countersigned_by": string | null,"created_at": string,"created_by": string,"id": string,"organization_id": string,"performer_id": string,"return_id": string | null,"signed_at": string | null,"signed_by": string | null,"snapshot": NonNullable<Json>,"status": string,"summary": string | null,"supersedes_id": string | null,"team_id": string,"version": number,"visit_id": string,"withdrawn_at": string | null,"withdrawn_by": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"correction_reason"?: string | null,"countersign_required": boolean,"countersigned_at"?: string | null,"countersigned_by"?: string | null,"created_at"?: string,"created_by": string,"id"?: string,"organization_id": string,"performer_id": string,"return_id"?: string | null,"signed_at"?: string | null,"signed_by"?: string | null,"snapshot": NonNullable<Json>,"status"?: string,"summary"?: string | null,"supersedes_id"?: string | null,"team_id": string,"version": number,"visit_id": string,"withdrawn_at"?: string | null,"withdrawn_by"?: string | null
                  }
                  Update: {
                    "case_id"?: string | null,"correction_reason"?: string | null,"countersign_required"?: boolean,"countersigned_at"?: string | null,"countersigned_by"?: string | null,"created_at"?: string,"created_by"?: string,"id"?: string,"organization_id"?: string,"performer_id"?: string,"return_id"?: string | null,"signed_at"?: string | null,"signed_by"?: string | null,"snapshot"?: NonNullable<Json>,"status"?: string,"summary"?: string | null,"supersedes_id"?: string | null,"team_id"?: string,"version"?: number,"visit_id"?: string,"withdrawn_at"?: string | null,"withdrawn_by"?: string | null
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_reports_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_reports_return_id_fkey"
      columns: ["return_id"]
isOneToOne: false
      referencedRelation: "visit_report_returns"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_reports_supersedes_id_fkey"
      columns: ["supersedes_id"]
isOneToOne: false
      referencedRelation: "visit_reports"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_reports_team_id_organization_id_fkey"
      columns: ["team_id","organization_id"]
isOneToOne: false
      referencedRelation: "teams"
      referencedColumns: ["id","organization_id"]
    },{
      foreignKeyName: "visit_reports_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_status_notes": {
                  Row: {
                    "actor_id": string,"at_door": boolean | null,"created_at": string,"disclosure_basis": string | null,"id": string,"idempotency_key": string,"kind": string,"note": string | null,"organization_id": string,"reason_code": string | null,"responsible_absent": boolean,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"at_door"?: boolean | null,"created_at"?: string,"disclosure_basis"?: string | null,"id"?: string,"idempotency_key": string,"kind": string,"note"?: string | null,"organization_id": string,"reason_code"?: string | null,"responsible_absent"?: boolean,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"at_door"?: boolean | null,"created_at"?: string,"disclosure_basis"?: string | null,"id"?: string,"idempotency_key"?: string,"kind"?: string,"note"?: string | null,"organization_id"?: string,"reason_code"?: string | null,"responsible_absent"?: boolean,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_status_notes_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_status_notes_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"visit_time_corrections": {
                  Row: {
                    "actor_id": string,"corrected_at": string,"created_at": string,"event_id": number,"id": number,"idempotency_key": string,"organization_id": string,"reason": string,"team_id": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"corrected_at": string,"created_at"?: string,"event_id": number,"id"?: never,"idempotency_key": string,"organization_id": string,"reason": string,"team_id"?: string | null,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"corrected_at"?: string,"created_at"?: string,"event_id"?: number,"id"?: never,"idempotency_key"?: string,"organization_id"?: string,"reason"?: string,"team_id"?: string | null,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_time_corrections_event_id_fkey"
      columns: ["event_id"]
isOneToOne: false
      referencedRelation: "visit_events"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_time_corrections_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "visit_time_corrections_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                },"working_time": {
                  Row: {
                    "day_end": string,"day_start": string,"id": boolean,"time_zone": string,"weekdays": (number)[]
                  }
                  ComputedFields: never
                  Insert: {
                    "day_end": string,"day_start": string,"id"?: boolean,"time_zone": string,"weekdays": (number)[]
                  }
                  Update: {
                    "day_end"?: string,"day_start"?: string,"id"?: boolean,"time_zone"?: string,"weekdays"?: (number)[]
                  }
                  Relationships: [
                    
                  ]
                },"working_time_facts": {
                  Row: {
                    "care_minutes": number | null,"created_at": string,"id": string,"organization_id": string,"pause_minutes": number | null,"performer_id": string | null,"report_id": string | null,"source": string,"supersedes_id": string | null,"team_id": string,"travel_minutes": number | null,"visit_date": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "care_minutes"?: number | null,"created_at"?: string,"id"?: string,"organization_id": string,"pause_minutes"?: number | null,"performer_id"?: string | null,"report_id"?: string | null,"source"?: string,"supersedes_id"?: string | null,"team_id": string,"travel_minutes"?: number | null,"visit_date": string,"visit_id": string
                  }
                  Update: {
                    "care_minutes"?: number | null,"created_at"?: string,"id"?: string,"organization_id"?: string,"pause_minutes"?: number | null,"performer_id"?: string | null,"report_id"?: string | null,"source"?: string,"supersedes_id"?: string | null,"team_id"?: string,"travel_minutes"?: number | null,"visit_date"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "working_time_facts_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "working_time_facts_report_id_fkey"
      columns: ["report_id"]
isOneToOne: false
      referencedRelation: "visit_reports"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "working_time_facts_supersedes_id_fkey"
      columns: ["supersedes_id"]
isOneToOne: false
      referencedRelation: "working_time_facts"
      referencedColumns: ["id"]
    },{
      foreignKeyName: "working_time_facts_visit_id_organization_id_fkey"
      columns: ["visit_id","organization_id"]
isOneToOne: false
      referencedRelation: "care_visits"
      referencedColumns: ["id","organization_id"]
    }
                  ]
                }
          }
          Views: {
            [_ in never]: never
          }
          Functions: {
            "accept_cover":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"accept_my_invitations":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"acknowledge_working_time_notice":
{ Args: { "p_idempotency_key": string,"p_text_version": string }; Returns: Json
                           },
"active_safety_alert_categories":
{ Args: Record<PropertyKey, never>; Returns: {
              "class": string,"code": string,"help_text": string,"label": string,"refuses_codes": boolean,"version": number
            }[]
                           },
"add_care_plan_item":
{ Args: { "p_case_id": string,"p_category": string,"p_frequency": string,"p_goal": string,"p_idempotency_key": string,"p_planned_minutes": number,"p_review_date": string,"p_service": string }; Returns: string
                           },
"add_team_member":
{ Args: { "p_idempotency_key": string,"p_qualification": string,"p_team_id": string,"p_user_id": string }; Returns: string
                           },
"admin_exception_rules":
{ Args: { "p_organization_id": string }; Returns: {
              "amount": number,"amount_direction": string,"default_amount": number,"default_escalate": number,"default_priority": string,"escalate_to_p1_after_hours": number,"exception_type": string,"is_default": boolean,"label": string,"max_amount": number,"max_escalate": number,"min_amount": number,"priority": string,"unit": string,"updated_at": string,"updated_by_name": string
            }[]
                           },
"admin_members":
{ Args: { "p_organization_id": string }; Returns: {
              "display_name": string,"email": string,"joined_at": string,"role": string,"teams": Json,"user_id": string
            }[]
                           },
"admin_response_deadlines":
{ Args: { "p_organization_id": string }; Returns: {
              "amount": number,"default_amount": number,"default_unit": string,"is_default": boolean,"referral_type": string,"unit": string,"updated_at": string,"updated_by_name": string
            }[]
                           },
"assign_team_coach":
{ Args: { "p_coach_name": string,"p_idempotency_key": string,"p_team_id": string }; Returns: string
                           },
"billing_preview":
{ Args: { "p_month": string }; Returns: {
              "billable_visits": number,"insurer_chf": number,"insurer_complete": boolean,"minutes_a": number,"minutes_b": number,"minutes_c": number,"not_billable": Json,"patient_on_file": boolean,"reference_validated": boolean,"residual_on_file": boolean,"team_id": string,"team_name": string
            }[]
                           },
"cancel_visit":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_reason_code": string,"p_visit_id": string }; Returns: string
                           },
"case_funding_facts":
{ Args: { "p_case_id": string }; Returns: {
              "case_id": string,"gp_named": boolean,"insurance_type": string,"insurer_name": string,"medical_order_status": string,"medical_order_valid_until": string,"open_tasks": (string)[],"ready_for_matching_at": string,"residence_canton": string,"residence_municipality": string
            }[]
                           },
"change_absence":
{ Args: { "p_absence_id": string,"p_idempotency_key": string,"p_until": string,"p_until_time": string,"p_withdraw": boolean }; Returns: Json
                           },
"close_case":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code": string }; Returns: string
                           },
"complete_case_task":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_kind": string }; Returns: string
                           },
"complete_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"confirm_working_day":
{ Args: { "p_date": string,"p_idempotency_key": string,"p_payload": Json }; Returns: Json
                           },
"continuity_by_case":
{ Args: { "p_month": string }; Returns: {
              "case_id": string,"client_label": string,"distinct_nurses": number,"primary_set": boolean,"primary_share_pct": number,"team_name": string,"visits": number
            }[]
                           },
"convert_partner_request":
{ Args: { "p_consent_confirmed": boolean,"p_facts": Json,"p_first_name": string,"p_idempotency_key": string,"p_last_name": string,"p_request_id": string }; Returns: Json
                           },
"correct_report":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_report_id": string,"p_summary": string }; Returns: Json
                           },
"correct_visit_time":
{ Args: { "p_corrected_at": string,"p_event_id": number,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"countersign_report":
{ Args: { "p_idempotency_key": string,"p_report_id": string }; Returns: Json
                           },
"cover_offers":
{ Args: Record<PropertyKey, never>; Returns: {
              "area": string,"closes_at": string,"minutes_a": number,"minutes_b": number,"minutes_c": number,"required_qualification": string,"services": (string)[],"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"create_report_draft":
{ Args: { "p_idempotency_key": string,"p_summary": string,"p_visit_id": string }; Returns: Json
                           },
"create_team":
{ Args: { "p_idempotency_key": string,"p_name": string,"p_organization_id": string,"p_region": string }; Returns: string
                           },
"deactivate_team":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_team_id": string }; Returns: string
                           },
"decide_matching_request":
{ Args: { "p_decision": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code"?: string,"p_request_id": string,"p_team_id": string }; Returns: string
                           },
"depart_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"end_member_access":
{ Args: { "p_idempotency_key": string,"p_reason_code": string,"p_user_id": string }; Returns: Json
                           },
"end_visit_not_completed":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_reason_code": string,"p_visit_id": string }; Returns: string
                           },
"export_working_month":
{ Args: { "p_idempotency_key": string,"p_month": string }; Returns: Json
                           },
"field_countersign_queue":
{ Args: Record<PropertyKey, never>; Returns: {
              "client_name": string,"kind": string,"performer_access_ended": string,"performer_name": string,"report_id": string,"returned": boolean,"returned_at": string,"signed_at": string,"team_name": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"field_door_notes":
{ Args: { "p_date": string }; Returns: {
              "access_notes": string,"case_id": string,"language_notes": string,"visit_id": string
            }[]
                           },
"field_notes":
{ Args: { "p_date": string }; Returns: {
              "content": string,"edited": boolean,"for_handover": boolean,"id": string,"kind": string,"own": boolean,"recorded_at": string,"source_date": string,"visit_id": string
            }[]
                           },
"field_quality":
{ Args: { "p_date": string }; Returns: {
              "at": string,"id": string,"kind": string,"label": string,"own": boolean,"person_name": string,"severity": string,"status": string,"visit_id": string
            }[]
                           },
"field_reports":
{ Args: { "p_date": string }; Returns: {
              "correction_reason": string,"countersign_required": boolean,"countersigned_at": string,"countersigned_by_name": string,"i_am_performer": boolean,"i_can_countersign": boolean,"i_can_return": boolean,"i_signed": boolean,"performer_access_ended": boolean,"performer_unavailable": boolean,"report_id": string,"return_reason": string,"returned": boolean,"returned_at": string,"returned_by_name": string,"returned_snapshot": Json,"signed_at": string,"signed_by_name": string,"snapshot": Json,"snapshot_hash": string,"status": string,"summary": string,"version": number,"visit_id": string
            }[]
                           },
"field_returned_reports":
{ Args: Record<PropertyKey, never>; Returns: {
              "client_name": string,"reason": string,"report_id": string,"returned_at": string,"returned_by_name": string,"team_name": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"field_safety_alerts":
{ Args: { "p_date": string }; Returns: {
              "actor_kind": string,"actor_name": string,"case_id": string,"category_class": string,"category_code": string,"category_label": string,"help_text": string,"note": string,"recorded_at": string,"refuses_codes": boolean,"source": string,"value": string,"visit_id": string
            }[]
                           },
"field_since_last":
{ Args: { "p_date": string }; Returns: {
              "at": string,"author": string,"detail": Json,"entry_id": string,"kind": string,"lookback": number,"rule": string,"since_date": string,"source_visit_date": string,"source_visit_start": string,"visit_id": string
            }[]
                           },
"field_visit_status_notes":
{ Args: { "p_date": string }; Returns: {
              "actor_kind": string,"actor_name": string,"actor_qualification": string,"actor_role": string,"at_door": boolean,"created_at": string,"disclosure_basis": string,"kind": string,"note": string,"reason_code": string,"responsible_absent": boolean,"visit_id": string
            }[]
                           },
"field_visits":
{ Args: { "p_date": string }; Returns: {
              "address": string,"care_goals": (string)[],"care_needs": (string)[],"case_id": string,"client_name": string,"events": Json,"is_needs_assessment": boolean,"ort": string,"pause_reason": string,"planned_minutes_a": number,"planned_minutes_b": number,"planned_minutes_c": number,"plz": string,"responsible_me": boolean,"responsible_set": boolean,"services_provided": (string)[],"status": string,"suspended": boolean,"team_id": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"final_report_visits":
{ Args: Record<PropertyKey, never>; Returns: {
              "visit_id": string
            }[]
                           },
"generate_billable_facts":
{ Args: { "p_month": string }; Returns: number
                           },
"handle_exception":
{ Args: { "p_idempotency_key": string,"p_key": string,"p_kind": string,"p_text": string }; Returns: string
                           },
"intake_cases":
{ Args: Record<PropertyKey, never>; Returns: {
              "access_notes": string,"care_needs": (string)[],"case_id": string,"client_name": string,"created_at": string,"expected_hours_per_week": number,"gp_named": boolean,"insurance_type": string,"insurer_name": string,"language_notes": string,"medical_order_status": string,"medical_order_valid_until": string,"missing": Json,"open_tasks": (string)[],"other_providers_active": boolean,"region": string,"requested_start": string,"residence_canton": string,"residence_municipality": string,"urgency": string
            }[]
                           },
"invite_member":
{ Args: { "p_display_name": string,"p_email": string,"p_idempotency_key": string,"p_organization_id": string,"p_qualification": string,"p_role": string,"p_team_id": string }; Returns: string
                           },
"lift_quality_hold":
{ Args: { "p_hold_id": string,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"link_returning_referral":
{ Args: { "p_case_id": string,"p_consent_confirmed": boolean,"p_facts": Json,"p_first_name": string,"p_idempotency_key": string,"p_last_name": string,"p_reason": string,"p_request_id": string }; Returns: Json
                           },
"linkable_cases":
{ Args: { "p_request_id": string }; Returns: {
              "case_id": string,"client_name": string,"lifecycle": string,"reason_code": string,"since": string,"team_name": string
            }[]
                           },
"matching_escalations":
{ Args: Record<PropertyKey, never>; Returns: {
              "created_at": string,"declines": Json,"eligible_teams": number,"matching_request_id": string,"reason": string,"referral_type": string,"region": string,"request_title": string,"response_due_at": string,"urgency": string
            }[]
                           },
"member_open_reports":
{ Args: { "p_user_id": string }; Returns: {
              "kind": string,"team_name": string,"visit_date": string
            }[]
                           },
"my_access_state":
{ Args: Record<PropertyKey, never>; Returns: Json
                           },
"my_covers":
{ Args: Record<PropertyKey, never>; Returns: {
              "area": string,"covered_at": string,"minutes_a": number,"minutes_b": number,"minutes_c": number,"services": (string)[],"status": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"my_push_state":
{ Args: Record<PropertyKey, never>; Returns: Json
                           },
"my_signals":
{ Args: Record<PropertyKey, never>; Returns: {
              "delivered_at": string,"operations_outside_app": boolean,"outside_none": boolean,"p1_at": string,"reason": string,"signal_id": string,"signal_kind": string,"taken_at": string,"taken_awaits_rn": boolean,"taken_by_me": boolean,"taken_by_name": string,"taken_by_qualification": string,"taker_access_ended": boolean,"team_id": string,"team_name": string,"time_start": string,"visit_date": string,"visit_id": string,"watched_now": boolean
            }[]
                           },
"my_working_day":
{ Args: { "p_date": string }; Returns: {
              "ends_at": string,"kind": string,"seq": number,"starts_at": string,"visit_no": number
            }[]
                           },
"my_working_day_versions":
{ Args: { "p_date": string }; Returns: {
              "break_minutes": number,"breaks_answer": string,"care_minutes": number,"confirmed_at": string,"day_end": string,"day_start": string,"entries": Json,"note": string,"outside_answer": string,"paid_minutes": number,"reason_code": string,"version": number
            }[]
                           },
"my_working_time_notice":
{ Args: Record<PropertyKey, never>; Returns: Json
                           },
"operations_exceptions":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"case_label": string,"closable": boolean,"comments": Json,"detail": string,"entity_id": string,"entity_type": string,"exception_key": string,"exception_type": string,"flags": (string)[],"label": string,"next_step": string,"owner_name": string,"priority": string,"region": string,"since": string,"taken": boolean,"taken_at": string,"taken_by_me": boolean,"team_name": string
            }[]
                           },
"ops_case_lifecycle":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"changed_at": string,"client_name": string,"expected_end": string,"last_kind": string,"last_reason": string,"lifecycle": string,"suspended_visits": number,"team_name": string
            }[]
                           },
"org_audit_read_log":
{ Args: { "p_organization_id": string }; Returns: {
              "entity_id": string,"entity_type": string,"purpose": string,"read_at": string,"reader_id": string,"rows_returned": number
            }[]
                           },
"pause_case":
{ Args: { "p_case_id": string,"p_expected_end": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code": string }; Returns: string
                           },
"pause_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"pilot_hypotheses":
{ Args: { "p_month": string }; Returns: {
              "base": number,"detail": string,"measure": string,"note": string,"organization_id": string,"suppressed": boolean,"team_id": string,"team_name": string,"too_few": boolean,"value": number
            }[]
                           },
"pilot_kpis":
{ Args: { "p_month": string }; Returns: {
              "base": number,"kpi": string,"note": string,"organization_id": string,"team_id": string,"team_name": string,"too_few": boolean,"value": number
            }[]
                           },
"plan_from_care_plan":
{ Args: { "p_case_id": string,"p_idempotency_key": string }; Returns: Json
                           },
"plan_visit":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_minutes_a": number,"p_minutes_b": number,"p_minutes_c": number,"p_needs_assessment": boolean,"p_responsible_user_id": string,"p_time_end": string,"p_time_start": string,"p_visit_date": string }; Returns: Json
                           },
"push_dispatch_claim":
{ Args: { "p_limit"?: number }; Returns: {
              "auth_secret": string,"endpoint": string,"kind": string,"p256dh": string,"ref_id": string,"subscription_id": string
            }[]
                           },
"push_dispatch_report":
{ Args: { "p_kind": string,"p_ref_id": string,"p_results": Json }; Returns: string
                           },
"read_audit_record":
{ Args: { "p_entity_id": string,"p_entity_type": string,"p_purpose": string }; Returns: {
              "actor_id": string,"actor_role": string,"changed": Json,"command": string,"occurred_at": string,"text_withheld": boolean,"withheld_keys": (string)[]
            }[]
                           },
"record_absence":
{ Args: { "p_from": string,"p_from_time": string,"p_idempotency_key": string,"p_team_id": string,"p_until": string,"p_until_time": string,"p_user_id": string }; Returns: Json
                           },
"record_gp_informed":
{ Args: { "p_case_id": string,"p_channel": string,"p_idempotency_key": string,"p_informed_on": string }; Returns: Json
                           },
"record_interruption_followup":
{ Args: { "p_decision": string,"p_idempotency_key": string,"p_note": string,"p_visit_id": string }; Returns: string
                           },
"record_no_show":
{ Args: { "p_at_door"?: boolean,"p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"record_no_show_outcome":
{ Args: { "p_basis"?: string,"p_idempotency_key": string,"p_outcome": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"record_observation":
{ Args: { "p_content": string,"p_for_handover": boolean,"p_idempotency_key": string,"p_supersedes_id": string,"p_visit_id": string }; Returns: string
                           },
"record_partner_request":
{ Args: { "p_city": string,"p_idempotency_key": string,"p_need_summary": string,"p_organization_id": string,"p_partner_name": string,"p_partner_type": string,"p_region": string,"p_request_title": string,"p_requested_services": (string)[],"p_time_info": string,"p_urgency": string }; Returns: string
                           },
"record_push_tap":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"record_quality_event":
{ Args: { "p_idempotency_key": string,"p_note": string,"p_occurred_at": string,"p_severity": string,"p_type_code": string,"p_visit_id": string }; Returns: Json
                           },
"record_safety_alert_value":
{ Args: { "p_case_id": string,"p_category": string,"p_idempotency_key": string,"p_note": string,"p_source": string,"p_value": string }; Returns: string
                           },
"refresh_team_plans":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"register_push_subscription":
{ Args: { "p_auth": string,"p_endpoint": string,"p_idempotency_key": string,"p_p256dh": string }; Returns: Json
                           },
"remove_planned_visit":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: Json
                           },
"remove_team_member":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_team_id": string,"p_user_id": string }; Returns: Json
                           },
"reopen_case":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"report_returns":
{ Args: { "p_visit_id": string }; Returns: {
              "reason": string,"report_id": string,"report_version": number,"return_id": string,"returned_at": string,"returned_by_name": string,"snapshot": Json,"snapshot_hash": string,"summary": string
            }[]
                           },
"reschedule_visit":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_time_end": string,"p_time_start": string,"p_visit_date": string,"p_visit_id": string }; Returns: Json
                           },
"reset_exception_rule":
{ Args: { "p_exception_type": string,"p_idempotency_key": string,"p_organization_id": string }; Returns: string
                           },
"restore_member_access":
{ Args: { "p_idempotency_key": string,"p_reason_code": string,"p_user_id": string }; Returns: Json
                           },
"resume_case":
{ Args: { "p_case_id": string,"p_idempotency_key": string }; Returns: string
                           },
"resume_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"retire_care_plan_item":
{ Args: { "p_idempotency_key": string,"p_item_id": string,"p_reason": string }; Returns: string
                           },
"return_report":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_report_id": string }; Returns: Json
                           },
"revoke_invitation":
{ Args: { "p_idempotency_key": string,"p_invitation_id": string }; Returns: string
                           },
"set_auto_planning":
{ Args: { "p_case_id": string,"p_enabled": boolean,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"set_care_plan_schedule":
{ Args: { "p_idempotency_key": string,"p_item_id": string,"p_period": string,"p_times": number,"p_weekdays": (number)[],"p_window_end": string,"p_window_start": string }; Returns: Json
                           },
"set_display_name":
{ Args: { "p_display_name": string,"p_idempotency_key": string,"p_organization_id": string,"p_user_id": string }; Returns: string
                           },
"set_exception_rule":
{ Args: { "p_amount": number,"p_escalate_to_p1_after_hours": number,"p_exception_type": string,"p_idempotency_key": string,"p_organization_id": string,"p_priority": string }; Returns: string
                           },
"set_member_qualification":
{ Args: { "p_idempotency_key": string,"p_qualification": string,"p_reason": string,"p_team_id": string,"p_user_id": string }; Returns: string
                           },
"set_member_role":
{ Args: { "p_idempotency_key": string,"p_organization_id": string,"p_reason": string,"p_role": string,"p_user_id": string }; Returns: string
                           },
"set_outside_push":
{ Args: { "p_enabled": boolean,"p_idempotency_key": string,"p_organization_id": string }; Returns: string
                           },
"set_primary_nurse":
{ Args: { "p_case_id": string,"p_deputy": string,"p_idempotency_key": string,"p_primary": string,"p_reason": string }; Returns: string
                           },
"set_quality_event_status":
{ Args: { "p_event_id": string,"p_idempotency_key": string,"p_note": string,"p_status": string }; Returns: string
                           },
"set_quality_hold":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"set_response_deadline":
{ Args: { "p_amount": number,"p_idempotency_key": string,"p_organization_id": string,"p_referral_type": string,"p_unit": string }; Returns: string
                           },
"set_team_priority":
{ Args: { "p_idempotency_key": string,"p_priority": boolean,"p_team_id": string }; Returns: string
                           },
"set_watched_hours":
{ Args: { "p_hours": Json,"p_idempotency_key": string,"p_organization_id": string }; Returns: string
                           },
"sign_report":
{ Args: { "p_idempotency_key": string,"p_report_id": string,"p_snapshot_hash": string }; Returns: Json
                           },
"signal_evaluator_health":
{ Args: Record<PropertyKey, never>; Returns: {
              "last_run_at": string,"organization_id": string,"running": boolean
            }[]
                           },
"start_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"sync_cover_offers":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"sync_exceptions":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"take_open_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: Json
                           },
"take_signal":
{ Args: { "p_idempotency_key": string,"p_signal_id": string }; Returns: Json
                           },
"team_absences":
{ Args: Record<PropertyKey, never>; Returns: {
              "absence_id": string,"ends_at": string,"is_me": boolean,"may_change": boolean,"member": string,"recorded_by_me": boolean,"starts_at": string,"team_id": string
            }[]
                           },
"team_case_lifecycle":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"changed_at": string,"client_name": string,"expected_end": string,"last_kind": string,"last_reason": string,"lifecycle": string,"suspended_visits": number,"team_name": string
            }[]
                           },
"team_cases":
{ Args: Record<PropertyKey, never>; Returns: {
              "care_needs": (string)[],"care_plan": Json,"case_id": string,"client_name": string,"deputy_nurse_id": string,"medical_order_status": string,"medical_order_valid_until": string,"members": Json,"needs_assessment_done": boolean,"open_tasks": (string)[],"primary_nurse_id": string,"proposed_primary_nurse_id": string,"region": string,"review_after_pause_reason": string,"team_id": string,"team_name": string,"upcoming": Json,"urgency": string
            }[]
                           },
"team_offers":
{ Args: Record<PropertyKey, never>; Returns: {
              "created_at": string,"expected_hours_per_week": number,"first_refusal_until": string,"matching_request_id": string,"my_team_declined": boolean,"region": string,"request_title": string,"requested_start": string,"required_qualification": string,"required_services": (string)[],"response_due_at": string,"returning_client": boolean,"team_id": string,"team_name": string,"urgency": string
            }[]
                           },
"team_open_reports":
{ Args: Record<PropertyKey, never>; Returns: {
              "access_ended_on": string,"correction_draft": number,"member_name": string,"returned": number,"team_name": string,"unsigned": number,"user_id": string
            }[]
                           },
"team_open_visits":
{ Args: { "p_from": string }; Returns: {
              "case_id": string,"client_name": string,"is_needs_assessment": boolean,"known_by": string,"known_by_me": boolean,"may_take": boolean,"overlaps_my_visit": string,"planned_minutes_a": number,"planned_minutes_b": number,"planned_minutes_c": number,"services_provided": (string)[],"team_id": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"team_plan_status":
{ Args: Record<PropertyKey, never>; Returns: {
              "auto_planning": boolean,"b_until": string,"blocked_reason": string,"case_id": string,"generated_ahead": number,"generated_on": string,"order_flagged": number,"unscheduled": Json
            }[]
                           },
"team_push_status":
{ Args: Record<PropertyKey, never>; Returns: {
              "active": boolean,"member_name": string,"team_id": string,"team_name": string,"user_id": string
            }[]
                           },
"team_visit_alerts":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"client_name": string,"detail": string,"exception_key": string,"exception_type": string,"flags": (string)[],"label": string,"priority": string,"since": string,"taken": boolean,"team_id": string,"team_name": string,"visit_id": string
            }[]
                           },
"uncovered_visits":
{ Args: Record<PropertyKey, never>; Returns: {
              "team_id": string,"team_name": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"unregister_push_subscription":
{ Args: { "p_endpoint": string,"p_idempotency_key": string }; Returns: string
                           },
"update_case_intake":
{ Args: { "p_case_id": string,"p_facts": Json,"p_idempotency_key": string,"p_reason"?: string }; Returns: Json
                           },
"update_report_draft":
{ Args: { "p_idempotency_key": string,"p_report_id": string,"p_summary": string }; Returns: Json
                           },
"update_team":
{ Args: { "p_idempotency_key": string,"p_name": string,"p_region": string,"p_team_id": string }; Returns: string
                           },
"visit_correction_history":
{ Args: { "p_visit_id": string }; Returns: {
              "corrected_by_me": boolean,"corrected_on": string,"correction_id": number,"corrector_name": string,"event_id": number,"event_type": string,"fact_countersigned_by_name": string,"fact_report_version": number,"full_trail": boolean,"in_billed_version": boolean,"new_at": string,"old_at": string,"reason": string,"recorded_at": string
            }[]
                           },
"visits_outside_watched_hours":
{ Args: { "p_own_teams"?: boolean }; Returns: {
              "organization_id": string,"team_id": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"withdraw_cover":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"withdraw_report_correction":
{ Args: { "p_idempotency_key": string,"p_report_id": string }; Returns: Json
                           }
          }
          Enums: {
            [_ in never]: never
          }
          CompositeTypes: {
            [_ in never]: never
          }
        }
}

type DatabaseWithoutInternals = Omit<Database, '__InternalSupabase'>

type DefaultSchema = DatabaseWithoutInternals[Extract<keyof Database, "public">]

export type Tables<
  DefaultSchemaTableNameOrOptions extends
    | keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
        DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? (DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"] &
      DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Views"])[TableName] extends {
      Row: infer R
    }
    ? R
    : never
  : DefaultSchemaTableNameOrOptions extends keyof (DefaultSchema["Tables"] & DefaultSchema["Views"])
  ? (DefaultSchema["Tables"] & DefaultSchema["Views"])[DefaultSchemaTableNameOrOptions] extends {
      Row: infer R
    }
    ? R
    : never
  : never

export type TablesInsert<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Insert: infer I
    }
    ? I
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Insert: infer I
    }
    ? I
    : never
  : never

export type TablesUpdate<
  DefaultSchemaTableNameOrOptions extends
    | keyof DefaultSchema["Tables"]
    | { schema: keyof DatabaseWithoutInternals },
  TableName extends DefaultSchemaTableNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"]
    : never = never
> = DefaultSchemaTableNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaTableNameOrOptions["schema"]]["Tables"][TableName] extends {
      Update: infer U
    }
    ? U
    : never
  : DefaultSchemaTableNameOrOptions extends keyof DefaultSchema["Tables"]
  ? DefaultSchema["Tables"][DefaultSchemaTableNameOrOptions] extends {
      Update: infer U
    }
    ? U
    : never
  : never

export type Enums<
  DefaultSchemaEnumNameOrOptions extends
    | keyof DefaultSchema["Enums"]
    | { schema: keyof DatabaseWithoutInternals },
  EnumName extends DefaultSchemaEnumNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"]
    : never = never
> = DefaultSchemaEnumNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[DefaultSchemaEnumNameOrOptions["schema"]]["Enums"][EnumName]
  : DefaultSchemaEnumNameOrOptions extends keyof DefaultSchema["Enums"]
  ? DefaultSchema["Enums"][DefaultSchemaEnumNameOrOptions]
  : never

export type CompositeTypes<
  PublicCompositeTypeNameOrOptions extends
    | keyof DefaultSchema["CompositeTypes"]
    | { schema: keyof DatabaseWithoutInternals },
  CompositeTypeName extends PublicCompositeTypeNameOrOptions extends {
    schema: keyof DatabaseWithoutInternals
  }
    ? keyof DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"]
    : never = never
> = PublicCompositeTypeNameOrOptions extends { schema: keyof DatabaseWithoutInternals }
  ? DatabaseWithoutInternals[PublicCompositeTypeNameOrOptions["schema"]]["CompositeTypes"][CompositeTypeName]
  : PublicCompositeTypeNameOrOptions extends keyof DefaultSchema["CompositeTypes"]
  ? DefaultSchema["CompositeTypes"][PublicCompositeTypeNameOrOptions]
  : never

export const Constants = {
  "public": {
          Enums: {
            
          }
        }
} as const
