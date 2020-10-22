Given /^I check containers cpu request for pod named #{QUOTED}:$/ do |pod_name, table|
    container_cpu_hash = table.rows_hash
    step %Q/I run the :get client command with:/, table(%{
        | n             | openshift-monitoring                                                           |
        | resource      | pods                                                                           |
        | resource_name | #{pod_name}                                                                    |
        | o             | go-template={{range.spec.containers}}{{.resources.requests.cpu}}{{"#"}}{{end}} |
      })
    cpus=@result[:stdout].split(/#/).map{|n| n.delete('m').to_i}
    step %Q/I run the :get client command with:/, table(%{
        | n             | openshift-monitoring                                         |
        | resource      | pods                                                         |
        | resource_name | #{pod_name}                                                  |
        | o             | go-template={{range.spec.containers}}{{.name}}{{"#"}}{{end}} |
      })
    containers=@result[:stdout].split(/#/)
    for i in 0..containers.length-1
        underlimit=container_cpu_hash.include?(containers[i])?cpus[i]<container_cpu_hash[containers[i]].to_i : cpus[i]<11
        raise "#{containers[i]} cpu limit #{cpus[i]} is over" unless underlimit    
    end    
end