extends RefCounted
class_name CampSystem

func rest(company) -> String:
	return company.rest()

func repair(company) -> String:
	return company.repair_armor()

func treat_wounds(company) -> String:
	return company.treat_wounds()
