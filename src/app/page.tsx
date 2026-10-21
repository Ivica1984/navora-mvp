import { redirect } from "next/navigation";
2
 
3
export default function HomePage() {
4
return redirect("/login");
5
}