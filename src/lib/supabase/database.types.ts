
export type Json = string | number | boolean | null | { [key: string]: Json | undefined } | Json[]

export type Database = {
  
  "public": {
          Tables: {
            "audit_events": {
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
                },"billable_facts": {
                  Row: {
                    "actual_care_minutes": number | null,"billable": boolean,"billable_minutes_a": number | null,"billable_minutes_b": number | null,"billable_minutes_c": number | null,"case_id": string,"created_at": string,"created_by": string,"id": string,"measured_care_minutes": number | null,"order_basis": string,"organization_id": string,"payer_chain": NonNullable<Json>,"planned_minutes_a": number,"planned_minutes_b": number,"planned_minutes_c": number,"reasons": (string)[],"report_id": string,"rule_version": string,"supersedes_id": string | null,"tariff_versions": NonNullable<Json>,"team_id": string,"visit_date": string,"visit_id": string,"warnings": (string)[]
                  }
                  ComputedFields: never
                  Insert: {
                    "actual_care_minutes"?: number | null,"billable": boolean,"billable_minutes_a"?: number | null,"billable_minutes_b"?: number | null,"billable_minutes_c"?: number | null,"case_id": string,"created_at"?: string,"created_by": string,"id"?: string,"measured_care_minutes"?: number | null,"order_basis": string,"organization_id": string,"payer_chain": NonNullable<Json>,"planned_minutes_a"?: number,"planned_minutes_b"?: number,"planned_minutes_c"?: number,"reasons"?: (string)[],"report_id": string,"rule_version"?: string,"supersedes_id"?: string | null,"tariff_versions": NonNullable<Json>,"team_id": string,"visit_date": string,"visit_id": string,"warnings"?: (string)[]
                  }
                  Update: {
                    "actual_care_minutes"?: number | null,"billable"?: boolean,"billable_minutes_a"?: number | null,"billable_minutes_b"?: number | null,"billable_minutes_c"?: number | null,"case_id"?: string,"created_at"?: string,"created_by"?: string,"id"?: string,"measured_care_minutes"?: number | null,"order_basis"?: string,"organization_id"?: string,"payer_chain"?: NonNullable<Json>,"planned_minutes_a"?: number,"planned_minutes_b"?: number,"planned_minutes_c"?: number,"reasons"?: (string)[],"report_id"?: string,"rule_version"?: string,"supersedes_id"?: string | null,"tariff_versions"?: NonNullable<Json>,"team_id"?: string,"visit_date"?: string,"visit_id"?: string,"warnings"?: (string)[]
                  }
                  Relationships: [
                    {
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
                    "id": string,"min_billable_minutes": number,"region": string,"source": string,"valid_from": string,"valid_to": string | null,"version": string
                  }
                  ComputedFields: never
                  Insert: {
                    "id"?: string,"min_billable_minutes": number,"region": string,"source": string,"valid_from": string,"valid_to"?: string | null,"version": string
                  }
                  Update: {
                    "id"?: string,"min_billable_minutes"?: number,"region"?: string,"source"?: string,"valid_from"?: string,"valid_to"?: string | null,"version"?: string
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
                    "billable": boolean | null,"case_id": string | null,"created_at": string,"id": string,"is_needs_assessment": boolean,"notes": string | null,"organization_id": string,"plan_generated": boolean,"plan_slot_date": string | null,"plan_slot_start": string | null,"planned_minutes_a": number | null,"planned_minutes_b": number | null,"planned_minutes_c": number | null,"responsible_user_id": string | null,"services_provided": (string)[] | null,"status": string | null,"suspended_at": string | null,"suspended_by": string | null,"team_id": string | null,"team_member_name": string | null,"time_end": string | null,"time_start": string | null,"visit_date": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "billable"?: boolean | null,"case_id"?: string | null,"created_at"?: string,"id"?: string,"is_needs_assessment"?: boolean,"notes"?: string | null,"organization_id": string,"plan_generated"?: boolean,"plan_slot_date"?: string | null,"plan_slot_start"?: string | null,"planned_minutes_a"?: number | null,"planned_minutes_b"?: number | null,"planned_minutes_c"?: number | null,"responsible_user_id"?: string | null,"services_provided"?: (string)[] | null,"status"?: string | null,"suspended_at"?: string | null,"suspended_by"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
                  }
                  Update: {
                    "billable"?: boolean | null,"case_id"?: string | null,"created_at"?: string,"id"?: string,"is_needs_assessment"?: boolean,"notes"?: string | null,"organization_id"?: string,"plan_generated"?: boolean,"plan_slot_date"?: string | null,"plan_slot_start"?: string | null,"planned_minutes_a"?: number | null,"planned_minutes_b"?: number | null,"planned_minutes_c"?: number | null,"responsible_user_id"?: string | null,"services_provided"?: (string)[] | null,"status"?: string | null,"suspended_at"?: string | null,"suspended_by"?: string | null,"team_id"?: string | null,"team_member_name"?: string | null,"time_end"?: string | null,"time_start"?: string | null,"visit_date"?: string | null
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
                },"case_tasks": {
                  Row: {
                    "case_id": string,"created_at": string,"done_at": string | null,"done_by": string | null,"id": string,"kind": string,"organization_id": string,"status": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id": string,"created_at"?: string,"done_at"?: string | null,"done_by"?: string | null,"id"?: string,"kind": string,"organization_id": string,"status"?: string
                  }
                  Update: {
                    "case_id"?: string,"created_at"?: string,"done_at"?: string | null,"done_by"?: string | null,"id"?: string,"kind"?: string,"organization_id"?: string,"status"?: string
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
                    "access_notes": string | null,"address": string | null,"assigned_team": string | null,"assigned_team_id": string | null,"auto_planning": boolean,"bedarf": string | null,"care_level": string | null,"care_needs": (string)[] | null,"cognitive_status": string | null,"created_at": string,"date_of_birth": string | null,"deputy_nurse_id": string | null,"diagnosis_tags": (string)[] | null,"emergency_contact_name": string | null,"emergency_contact_phone": string | null,"expected_hours_per_week": number | null,"first_name": string | null,"gender": string | null,"gp_named": boolean | null,"id": string,"insurance_provider": string | null,"insurance_type": string | null,"insurer_name": string | null,"intake_consent_confirmed_at": string | null,"intake_consent_confirmed_by": string | null,"language_notes": string | null,"last_name": string | null,"lifecycle": string,"medical_order_status": string | null,"medical_order_valid_until": string | null,"mobility_status": string | null,"name": string | null,"needs_assessment_done_at": string | null,"next_step": string | null,"notes": string | null,"organization_id": string,"ort": string | null,"other_providers_active": boolean | null,"phone": string | null,"plan_generated_on": string | null,"plz": string | null,"primary_nurse_id": string | null,"ready_for_matching_at": string | null,"referral_source": string | null,"region": string | null,"reopened_at": string | null,"requested_start": string | null,"residence_canton": string | null,"residence_municipality": string | null,"source_partner_request_id": string | null,"start_date": string | null,"status": string | null,"time_info": string | null,"urgency": string | null
                  }
                  ComputedFields: never
                  Insert: {
                    "access_notes"?: string | null,"address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"auto_planning"?: boolean,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"deputy_nurse_id"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"expected_hours_per_week"?: number | null,"first_name"?: string | null,"gender"?: string | null,"gp_named"?: boolean | null,"id"?: string,"insurance_provider"?: string | null,"insurance_type"?: string | null,"insurer_name"?: string | null,"intake_consent_confirmed_at"?: string | null,"intake_consent_confirmed_by"?: string | null,"language_notes"?: string | null,"last_name"?: string | null,"lifecycle"?: string,"medical_order_status"?: string | null,"medical_order_valid_until"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"needs_assessment_done_at"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id": string,"ort"?: string | null,"other_providers_active"?: boolean | null,"phone"?: string | null,"plan_generated_on"?: string | null,"plz"?: string | null,"primary_nurse_id"?: string | null,"ready_for_matching_at"?: string | null,"referral_source"?: string | null,"region"?: string | null,"reopened_at"?: string | null,"requested_start"?: string | null,"residence_canton"?: string | null,"residence_municipality"?: string | null,"source_partner_request_id"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
                  }
                  Update: {
                    "access_notes"?: string | null,"address"?: string | null,"assigned_team"?: string | null,"assigned_team_id"?: string | null,"auto_planning"?: boolean,"bedarf"?: string | null,"care_level"?: string | null,"care_needs"?: (string)[] | null,"cognitive_status"?: string | null,"created_at"?: string,"date_of_birth"?: string | null,"deputy_nurse_id"?: string | null,"diagnosis_tags"?: (string)[] | null,"emergency_contact_name"?: string | null,"emergency_contact_phone"?: string | null,"expected_hours_per_week"?: number | null,"first_name"?: string | null,"gender"?: string | null,"gp_named"?: boolean | null,"id"?: string,"insurance_provider"?: string | null,"insurance_type"?: string | null,"insurer_name"?: string | null,"intake_consent_confirmed_at"?: string | null,"intake_consent_confirmed_by"?: string | null,"language_notes"?: string | null,"last_name"?: string | null,"lifecycle"?: string,"medical_order_status"?: string | null,"medical_order_valid_until"?: string | null,"mobility_status"?: string | null,"name"?: string | null,"needs_assessment_done_at"?: string | null,"next_step"?: string | null,"notes"?: string | null,"organization_id"?: string,"ort"?: string | null,"other_providers_active"?: boolean | null,"phone"?: string | null,"plan_generated_on"?: string | null,"plz"?: string | null,"primary_nurse_id"?: string | null,"ready_for_matching_at"?: string | null,"referral_source"?: string | null,"region"?: string | null,"reopened_at"?: string | null,"requested_start"?: string | null,"residence_canton"?: string | null,"residence_municipality"?: string | null,"source_partner_request_id"?: string | null,"start_date"?: string | null,"status"?: string | null,"time_info"?: string | null,"urgency"?: string | null
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
                },"exception_rules": {
                  Row: {
                    "amount": number | null,"escalate_to_p1_after_hours": number | null,"exception_type": string,"label": string,"next_step": string,"priority": string,"unit": string | null,"updated_at": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount"?: number | null,"escalate_to_p1_after_hours"?: number | null,"exception_type": string,"label": string,"next_step": string,"priority": string,"unit"?: string | null,"updated_at"?: string
                  }
                  Update: {
                    "amount"?: number | null,"escalate_to_p1_after_hours"?: number | null,"exception_type"?: string,"label"?: string,"next_step"?: string,"priority"?: string,"unit"?: string | null,"updated_at"?: string
                  }
                  Relationships: [
                    
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
                    "case_id": string | null,"created_at": string,"id": string,"notes": string | null,"organization_id": string,"referral_type": string | null,"region": string,"request_title": string,"required_qualification": string | null,"required_services": (string)[] | null,"response_due_at": string | null,"selected_team_id": string | null,"status": string,"urgency": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id": string,"referral_type"?: string | null,"region": string,"request_title": string,"required_qualification"?: string | null,"required_services"?: (string)[] | null,"response_due_at"?: string | null,"selected_team_id"?: string | null,"status"?: string,"urgency": string
                  }
                  Update: {
                    "case_id"?: string | null,"created_at"?: string,"id"?: string,"notes"?: string | null,"organization_id"?: string,"referral_type"?: string | null,"region"?: string,"request_title"?: string,"required_qualification"?: string | null,"required_services"?: (string)[] | null,"response_due_at"?: string | null,"selected_team_id"?: string | null,"status"?: string,"urgency"?: string
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
                },"tariff_rates": {
                  Row: {
                    "amount": number,"category": string | null,"id": string,"payer": string,"region": string,"source": string,"unit": string,"valid_from": string,"valid_to": string | null,"version": string
                  }
                  ComputedFields: never
                  Insert: {
                    "amount": number,"category"?: string | null,"id"?: string,"payer": string,"region": string,"source": string,"unit": string,"valid_from": string,"valid_to"?: string | null,"version": string
                  }
                  Update: {
                    "amount"?: number,"category"?: string | null,"id"?: string,"payer"?: string,"region"?: string,"source"?: string,"unit"?: string,"valid_from"?: string,"valid_to"?: string | null,"version"?: string
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
                    "care_focus": string | null,"coach_name": string | null,"created_at": string,"id": string,"lead_name": string | null,"name": string,"next_step": string | null,"open_slots": number | null,"organization_id": string,"priority": boolean | null,"region": string | null,"status": string | null,"utilization": number | null
                  }
                  ComputedFields: never
                  Insert: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"id"?: string,"lead_name"?: string | null,"name": string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id": string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
                  }
                  Update: {
                    "care_focus"?: string | null,"coach_name"?: string | null,"created_at"?: string,"id"?: string,"lead_name"?: string | null,"name"?: string,"next_step"?: string | null,"open_slots"?: number | null,"organization_id"?: string,"priority"?: boolean | null,"region"?: string | null,"status"?: string | null,"utilization"?: number | null
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
                    "actor_id": string,"after": Json | null,"before": Json | null,"case_id": string | null,"change": string,"changed_at": string,"id": number,"organization_id": string,"reason": string | null,"team_id": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"after"?: Json | null,"before"?: Json | null,"case_id"?: string | null,"change": string,"changed_at"?: string,"id"?: never,"organization_id": string,"reason"?: string | null,"team_id"?: string | null,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"after"?: Json | null,"before"?: Json | null,"case_id"?: string | null,"change"?: string,"changed_at"?: string,"id"?: never,"organization_id"?: string,"reason"?: string | null,"team_id"?: string | null,"visit_id"?: string
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
                },"visit_reports": {
                  Row: {
                    "case_id": string | null,"correction_reason": string | null,"countersign_required": boolean,"countersigned_at": string | null,"countersigned_by": string | null,"created_at": string,"created_by": string,"id": string,"organization_id": string,"performer_id": string,"signed_at": string | null,"signed_by": string | null,"snapshot": NonNullable<Json>,"status": string,"summary": string | null,"supersedes_id": string | null,"team_id": string,"version": number,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "case_id"?: string | null,"correction_reason"?: string | null,"countersign_required": boolean,"countersigned_at"?: string | null,"countersigned_by"?: string | null,"created_at"?: string,"created_by": string,"id"?: string,"organization_id": string,"performer_id": string,"signed_at"?: string | null,"signed_by"?: string | null,"snapshot": NonNullable<Json>,"status"?: string,"summary"?: string | null,"supersedes_id"?: string | null,"team_id": string,"version": number,"visit_id": string
                  }
                  Update: {
                    "case_id"?: string | null,"correction_reason"?: string | null,"countersign_required"?: boolean,"countersigned_at"?: string | null,"countersigned_by"?: string | null,"created_at"?: string,"created_by"?: string,"id"?: string,"organization_id"?: string,"performer_id"?: string,"signed_at"?: string | null,"signed_by"?: string | null,"snapshot"?: NonNullable<Json>,"status"?: string,"summary"?: string | null,"supersedes_id"?: string | null,"team_id"?: string,"version"?: number,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "visit_reports_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
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
                    "actor_id": string,"created_at": string,"id": string,"idempotency_key": string,"kind": string,"note": string | null,"organization_id": string,"reason_code": string | null,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "actor_id": string,"created_at"?: string,"id"?: string,"idempotency_key": string,"kind": string,"note"?: string | null,"organization_id": string,"reason_code"?: string | null,"visit_id": string
                  }
                  Update: {
                    "actor_id"?: string,"created_at"?: string,"id"?: string,"idempotency_key"?: string,"kind"?: string,"note"?: string | null,"organization_id"?: string,"reason_code"?: string | null,"visit_id"?: string
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
                    "care_minutes": number | null,"created_at": string,"id": string,"organization_id": string,"pause_minutes": number | null,"performer_id": string | null,"team_id": string,"travel_minutes": number | null,"visit_date": string,"visit_id": string
                  }
                  ComputedFields: never
                  Insert: {
                    "care_minutes"?: number | null,"created_at"?: string,"id"?: string,"organization_id": string,"pause_minutes"?: number | null,"performer_id"?: string | null,"team_id": string,"travel_minutes"?: number | null,"visit_date": string,"visit_id": string
                  }
                  Update: {
                    "care_minutes"?: number | null,"created_at"?: string,"id"?: string,"organization_id"?: string,"pause_minutes"?: number | null,"performer_id"?: string | null,"team_id"?: string,"travel_minutes"?: number | null,"visit_date"?: string,"visit_id"?: string
                  }
                  Relationships: [
                    {
      foreignKeyName: "working_time_facts_organization_id_fkey"
      columns: ["organization_id"]
isOneToOne: false
      referencedRelation: "organizations"
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
            "add_care_plan_item":
{ Args: { "p_case_id": string,"p_category": string,"p_frequency": string,"p_goal": string,"p_idempotency_key": string,"p_planned_minutes": number,"p_review_date": string,"p_service": string }; Returns: string
                           },
"assign_team_coach":
{ Args: { "p_coach_name": string,"p_idempotency_key": string,"p_team_id": string }; Returns: string
                           },
"billing_preview":
{ Args: { "p_month": string }; Returns: {
              "billable_visits": number,"insurer_chf": number,"insurer_complete": boolean,"minutes_a": number,"minutes_b": number,"minutes_c": number,"not_billable": Json,"patient_on_file": boolean,"residual_on_file": boolean,"team_id": string,"team_name": string
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
"close_case":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code": string }; Returns: string
                           },
"complete_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
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
"create_report_draft":
{ Args: { "p_idempotency_key": string,"p_summary": string,"p_visit_id": string }; Returns: Json
                           },
"decide_matching_request":
{ Args: { "p_decision": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code"?: string,"p_request_id": string,"p_team_id": string }; Returns: string
                           },
"depart_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"field_notes":
{ Args: { "p_date": string }; Returns: {
              "content": string,"edited": boolean,"for_handover": boolean,"id": string,"kind": string,"own": boolean,"recorded_at": string,"source_date": string,"visit_id": string
            }[]
                           },
"field_quality":
{ Args: { "p_date": string }; Returns: {
              "at": string,"id": string,"kind": string,"label": string,"own": boolean,"severity": string,"status": string,"visit_id": string
            }[]
                           },
"field_reports":
{ Args: { "p_date": string }; Returns: {
              "correction_reason": string,"countersign_required": boolean,"countersigned_at": string,"i_am_performer": boolean,"i_can_countersign": boolean,"i_signed": boolean,"report_id": string,"signed_at": string,"snapshot": Json,"status": string,"summary": string,"version": number,"visit_id": string
            }[]
                           },
"field_visit_status_notes":
{ Args: { "p_date": string }; Returns: {
              "created_at": string,"kind": string,"note": string,"reason_code": string,"visit_id": string
            }[]
                           },
"field_visits":
{ Args: { "p_date": string }; Returns: {
              "address": string,"care_goals": (string)[],"care_needs": (string)[],"case_id": string,"client_name": string,"events": Json,"is_needs_assessment": boolean,"ort": string,"planned_minutes_a": number,"planned_minutes_b": number,"planned_minutes_c": number,"plz": string,"responsible_me": boolean,"responsible_set": boolean,"services_provided": (string)[],"status": string,"team_id": string,"team_name": string,"time_end": string,"time_start": string,"visit_date": string,"visit_id": string
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
"lift_quality_hold":
{ Args: { "p_hold_id": string,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"matching_escalations":
{ Args: Record<PropertyKey, never>; Returns: {
              "created_at": string,"declines": Json,"eligible_teams": number,"matching_request_id": string,"reason": string,"referral_type": string,"region": string,"request_title": string,"response_due_at": string,"urgency": string
            }[]
                           },
"operations_exceptions":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"case_label": string,"comments": Json,"detail": string,"entity_id": string,"entity_type": string,"exception_key": string,"exception_type": string,"label": string,"next_step": string,"priority": string,"region": string,"since": string,"taken": boolean,"taken_at": string,"taken_by_me": boolean,"team_name": string
            }[]
                           },
"pause_case":
{ Args: { "p_case_id": string,"p_expected_end": string,"p_idempotency_key": string,"p_reason": string,"p_reason_code": string }; Returns: string
                           },
"pause_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"plan_from_care_plan":
{ Args: { "p_case_id": string,"p_idempotency_key": string }; Returns: Json
                           },
"plan_visit":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_minutes_a": number,"p_minutes_b": number,"p_minutes_c": number,"p_needs_assessment": boolean,"p_responsible_user_id": string,"p_time_end": string,"p_time_start": string,"p_visit_date": string }; Returns: Json
                           },
"record_no_show":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"record_no_show_outcome":
{ Args: { "p_idempotency_key": string,"p_outcome": string,"p_reason": string,"p_visit_id": string }; Returns: string
                           },
"record_observation":
{ Args: { "p_content": string,"p_for_handover": boolean,"p_idempotency_key": string,"p_supersedes_id": string,"p_visit_id": string }; Returns: string
                           },
"record_partner_request":
{ Args: { "p_city": string,"p_idempotency_key": string,"p_need_summary": string,"p_organization_id": string,"p_partner_name": string,"p_partner_type": string,"p_region": string,"p_request_title": string,"p_requested_services": (string)[],"p_time_info": string,"p_urgency": string }; Returns: string
                           },
"record_quality_event":
{ Args: { "p_idempotency_key": string,"p_note": string,"p_occurred_at": string,"p_severity": string,"p_type_code": string,"p_visit_id": string }; Returns: Json
                           },
"refresh_team_plans":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"remove_planned_visit":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_visit_id": string }; Returns: Json
                           },
"reopen_case":
{ Args: { "p_case_id": string,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"reschedule_visit":
{ Args: { "p_idempotency_key": string,"p_reason": string,"p_time_end": string,"p_time_start": string,"p_visit_date": string,"p_visit_id": string }; Returns: Json
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
"set_auto_planning":
{ Args: { "p_case_id": string,"p_enabled": boolean,"p_idempotency_key": string,"p_reason": string }; Returns: string
                           },
"set_care_plan_schedule":
{ Args: { "p_idempotency_key": string,"p_item_id": string,"p_period": string,"p_times": number,"p_weekdays": (number)[],"p_window_end": string,"p_window_start": string }; Returns: Json
                           },
"set_member_qualification":
{ Args: { "p_idempotency_key": string,"p_qualification": string,"p_reason": string,"p_team_id": string,"p_user_id": string }; Returns: string
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
"sign_report":
{ Args: { "p_idempotency_key": string,"p_report_id": string }; Returns: Json
                           },
"start_visit":
{ Args: { "p_idempotency_key": string,"p_visit_id": string }; Returns: string
                           },
"sync_exceptions":
{ Args: Record<PropertyKey, never>; Returns: number
                           },
"team_case_lifecycle":
{ Args: Record<PropertyKey, never>; Returns: {
              "case_id": string,"changed_at": string,"client_name": string,"expected_end": string,"last_kind": string,"last_reason": string,"lifecycle": string,"suspended_visits": number,"team_name": string
            }[]
                           },
"team_cases":
{ Args: Record<PropertyKey, never>; Returns: {
              "care_needs": (string)[],"care_plan": Json,"case_id": string,"client_name": string,"deputy_nurse_id": string,"medical_order_status": string,"medical_order_valid_until": string,"members": Json,"needs_assessment_done": boolean,"open_tasks": (string)[],"primary_nurse_id": string,"region": string,"team_id": string,"team_name": string,"upcoming": Json,"urgency": string
            }[]
                           },
"team_offers":
{ Args: Record<PropertyKey, never>; Returns: {
              "created_at": string,"expected_hours_per_week": number,"matching_request_id": string,"my_team_declined": boolean,"region": string,"request_title": string,"requested_start": string,"required_qualification": string,"required_services": (string)[],"response_due_at": string,"team_id": string,"team_name": string,"urgency": string
            }[]
                           },
"team_plan_status":
{ Args: Record<PropertyKey, never>; Returns: {
              "auto_planning": boolean,"b_until": string,"blocked_reason": string,"case_id": string,"generated_ahead": number,"generated_on": string,"unscheduled": Json
            }[]
                           },
"uncovered_visits":
{ Args: Record<PropertyKey, never>; Returns: {
              "team_id": string,"team_name": string,"time_start": string,"visit_date": string,"visit_id": string
            }[]
                           },
"update_case_intake":
{ Args: { "p_case_id": string,"p_facts": Json,"p_idempotency_key": string,"p_reason"?: string }; Returns: Json
                           },
"update_report_draft":
{ Args: { "p_idempotency_key": string,"p_report_id": string,"p_summary": string }; Returns: Json
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
