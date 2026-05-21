extends RefCounted
class_name CampSystem

func rest(company: CompanyState) -> String:
	return company.rest()

func repair(company: CompanyState) -> String:
	return company.repair_armor()

func treat_wounds(company: CompanyState) -> String:
	return company.treat_wounds()
